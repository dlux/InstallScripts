#!/usr/bin/env python

import atexit
import fileinput
import functools
import importlib
import io
import json
import os
import re
import subunit
import subprocess
import sys
import tempfile
import testtools

from subunit.filters import run_tests_from_stream


SUCCESS = []
SKIPS = []
FAILS = []
ADDPROP_FAIL = []
SERVICE_CLIENTS = {}
SCHEMAS = {}
TC_NAMES = []


def find(stdin):
    """
    Fires the analysis of stack trace
    """
    stream = subunit.ByteStreamToStreamResult(stdin,
                                              non_subunit_name='stdout')
    outcome = testtools.StreamToDict(functools.partial(show_outcome,
                                                       sys.stdout))
    summary = testtools.StreamSummary()
    result = testtools.CopyStreamResult([outcome, summary])
    result.startTestRun()
    try:
        stream.run(result)
    finally:
        result.stopTestRun()


def find_additionalProperties_in_traceback(traceback):
    '''
    Analize a single error string stack trace:
        Get error data for InvalidHTTPResponseBody errors
        Get serverclient and methods that failed {service1: [m1, m2]}
        Get the schema holding additionalProperties [pro1][prop2]
    '''
    # Define regexes to look for
    erregex = "tempest.lib.exceptions.InvalidHTTPResponseBody"
    serviceregex = ".*.tempest/lib/services/compute/"
    additional_props_err = "Failed validating 'additionalProperties'"
    properties_regex = re.compile(additional_props_err)

    # Define things to find
    error_msg = ""
    module_name = ""
    method_name = ""
    partial_schema =""
 
    # Analize error only when it is due to validating additional properties
    if not properties_regex.search(traceback):
        return False

    # Get error message
    err = traceback.split(erregex)
    error_msg = err[1] if len(err) >= 2 else None 

    # Get service client and method
    temp_line = re.search(serviceregex+"(.*)\n", traceback).group(1)
    if temp_line:
        module_name = re.sub("_client.py.*", "", temp_line)
        method_name = re.sub(".*.in.", "", temp_line)
    else:
        print("ERROR: UNABLE TO DETERMINE SCHEMA FOR ERROR %s" % str(error_msg))

    # Get partial schema
    partial_schema = re.search(".*.in.schema(.*):", traceback).group(1)
    #partial_schema = re.sub("[\[]", ",", partial_schema)
    partial_schema = "['response_body']" + partial_schema + "['additionalProperties']"

    SCHEMAS[module_name] = {method_name: partial_schema}

    if error_msg:
        return error_msg.split('\n')[1:]

    return False


def show_outcome(stream, test):
    """
    Prints failed test cases due to additional Properties issue
    """
    #global RESULTS
    status = test['status']
    if status == 'exists':
        return
    if status == 'fail':
        for raw_name in test['details']:
            name = raw_name.split(':')[0]
            detail = test['details'][raw_name]
            if detail.content_type.type == 'test':
                detail.content_type.type = 'text'
            if name == 'traceback':
                traceback = detail.as_text()
                res = find_additionalProperties_in_traceback(traceback)
                if isinstance(res, list):
                    title = (
                        "%s Failed with AdditionalProperties jsonschema "
                        "failure" % test['id'])
                    stream.write("\n%s\n%s\n" % (title, ('~' * len(title))))
                    for line in res:
                        line = line.encode('utf8')
                        stream.write("%s\n" % line)
                    stream.write('\n\n')
                    ADDPROP_FAIL.append(test)
                    tc_name = re.search("^setUpClass..(.*)\)", test['id'])
                    if tc_name:
                        TC_NAMES.append(tc_name.group(1))
                    else:
                        TC_NAMES.append(test['id'])
                        
                    break
        else:
            FAILS.append(test)
    elif status == 'success' or status == 'xfail':
        SUCCESS.append(test)
    elif status == 'skip':
        SKIPS.append(test)


def _create_whitelist():
    """
    Create a whitelist (failed TCs names as regex)
    One regex per line
    """
    def delete_temp_file(file_path):
        if os.path.isfile(file_path):
            os.remove(file_path)

    # create whitelist from TC name regexes
    white_list = tempfile.NamedTemporaryFile(delete=False)
    for test_regex in TC_NAMES:
        white_list.write("%s\n" % test_regex)
    white_list.flush()
    # Register the created file for cleanup.
    atexit.register(delete_temp_file, white_list.name)
    return white_list.name


def _patch_tempest_shema(tempest_dir):
    """
       Patch Tempest by modifying the schema.
       Set failed schema value to True
    """

    print "Patching Tempest Schemas."
    os.chdir(tempest_dir)
    activate_this_file = os.path.join(tempest_dir,".venv", "bin", "activate_this.py")
    # Activate environment if any, otherwise assume tempest is installed globally
    if os.path.isfile(activate_this_file):
        execfile(activate_this_file, dict(__file__=activate_this_file))
    os.chdir(tempest_dir)

    # Find schema to patch
    schemas_path = "tempest.lib.api_schema.response.compute.v2_1."
    init_file = 'tempest/lib/api_schema/response/compute/v2_1/__init__.py'

    # Get schema(s) and patch them
    for module_name in SCHEMAS.keys():

        module = importlib.import_module(schemas_path + module_name)
        print('module imported.')
        
        with open(init_file, 'a+') as f:
            f.write("import " + module_name + "\n")
        
        # Get all module schemas
        all_schemas = module.__dict__.keys()

        for method in SCHEMAS[module_name].keys():

            # Get all schemas that start with method and patch them all
            all_met = [elem for elem in all_schemas if elem.startswith(method)]

            for attr in all_met:

                # Patch schema patch
                _line = "%s.%s%s=True" % (module_name, attr, SCHEMAS[module_name][method])

                with open(init_file, 'a+') as f:                    
                    f.write(_line + "\n")

    print ('Tempest schemas patched.')


def _run_tempest_patched(tempest_dir, config_file):
    """
    Run tempest from the failed TCs whitelist via ostestr
    Called after find() and _patch_tempest_schema()
    """
    print("Run Tempest")
    os.chdir(tempest_dir)
    os.environ["TEMPEST_CONFIG_DIR"] = os.path.abspath(
            os.path.dirname(config_file))
    os.environ["TEMPEST_CONFIG"] = os.path.basename(config_file)
    white_list = _create_whitelist()
    wrapper = os.path.join(tempest_dir, 'tools', 'with_venv.sh')
    cmd = [wrapper, 'ostestr', '--serial', '-w', white_list]
    # Execute the ostestr command in a subprocess.
    process = subprocess.Popen(cmd, stderr=None)
    process.communicate()


def _clean_tempest_patch(tempest_dir):
    """
    Clean schemaspath.v2_1.__init__.py 
    """
    print "Cleaning Tempest Schemas patch"
    init_file = tempest_dir + '/tempest/lib/api_schema/response/compute/v2_1/__init__.py'
    open(init_file, 'w').close()


'''
def _patch_tempest_service_client(tempest_dir):
    '' '
    Patch Tempest by modifying the service client method
       Comment self.validate_response call directly on the file
    '' '
    client_path = os.path.dirname("tempest/lib/services/compute/")

    # Patch affected client_service.methods by skipping schema validation
    for name in SERVICE_CLIENTS.keys():
        methods = SERVICE_CLIENTS[name]
        file_name = os.path.join(tempest_dir, client_path, name)

        if not os.path.isfile(file_name):
            print "Unable to patch %s. File does not exists" % file_name
            continue

        # Patch tempest clients method by commenting validation line
        f = fileinput.input(file_name, inplace=True)
        errors = []
        for f_line in f:
            found = None
            for method in methods:
                # Find method to patch
                if ('def %s(' % method) in f_line:
                    sys.stdout.write(f_line)

                    # Continue reading lines until find validate response call
                    while(True):
                        f_line = f.next()
                        if not f_line or ' def ' in f_line:
                            # Reach end of method or EOF
                            errors.append("Unable to patch %s %s. Method not"
                                          " found" % file_name, method)
                            break

                        if 'self.validate_response' in f_line:
                            # Comment line in the file
                            sys.stdout.write('# %s' % f_line)
                            found = method
                            break
                        sys.stdout.write(f_line)
                    if found:
                        break
            if found:
                methods.remove(found)
            else:
                sys.stdout.write(f_line)

        f.close()
        if errors:
            for e in errors:
                print e 
'''


def printSummary():
    print("\n\n------------------------------------------------------------------")
    print("Failed due to schemas:")
    print(SCHEMAS)
    print("Test regex")
    print(TC_NAMES)
    print("\n\n------------------------------------------------------------------")
    print("%s Tests Failed" % len(FAILS))
    print("%s Tests Failed with AdditionalProperties" % len(ADDPROP_FAIL))
    print("%s Tests Skipped" % len(SKIPS))
    print("%s Tests Passed" % len(SUCCESS))
    print("To see the full details run this subunit stream through subunit-trace")
    print("\n\n------------------------------------------------------------------")


def main():
    """
    Main program flow    
    """
    
    args = sys.argv[1:]
    if len(args) < 3:
        print("Usage: python find_additional_properties <subunit_file> <configuration_file> <tempest_dir>")
        print("Assume Tempest installation is at virtual environment <tempest_dir>/.venv or global access")
        exit(1)

    subunit_file = args[0]
    config_file = args[1]
    tempest_dir = args[2]
    
    # Convert subunit file stream to V2 stream
    input_stream = open(subunit_file, 'rb')    
    v2_stream = io.BytesIO()
    run_tests_from_stream(input_stream,
                          testtools.ExtendedToStreamDecorator(
                                    subunit.StreamResultToBytes(v2_stream)))
    # Find additional properties on the stacktrace
    print("Ready to look for additional properties on the error trace.")
    v2_stream.seek(0)
    find(v2_stream)
    v2_stream.close()
    
    printSummary()

    #print("Ready to patch Tempest: commenting schema_validation at service client file.")
    #_patch_tempest_service_client(tempest_dir)
    
    # Patch tempest schema via __init__.py
    print("Ready to patch Tempest: Set schemas to false.")
    _patch_tempest_shema(tempest_dir)
    
    # Run tempest patched
    _run_tempest_patched(tempest_dir, config_file)
    
    # Clean patch
    _clean_tempest_patch(tempest_dir)


if __name__ == '__main__':
    main()
