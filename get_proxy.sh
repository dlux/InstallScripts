#!/bin/bash

# ====================================================
# This script creates a proxy environment variable.
# The intention is to reuse this parameter as entry in other installation scripts
# without affecting the system.
# ====================================================

# Uncomment the following line to debug this script
#set -o xtrace

source common_functions

function PrintHelp {
    echo " "
    echo "Script will create a proxy environment variable gathering information from given file."
    echo "To be reused by other scripts without altering system."
    echo " "
    echo "Usage:"
    echo "     get_proxy [--file | -f] <filePath>"
    echo " "
    echo "     --file | -f <filePath>   Pass the full file name where proxy information lives. See proxyrc.sample to see file sintaxis."
    echo "     --help | -h              Prints current help text. "
    echo " "
    exit 1
}

while [[ ${1} ]]; do
  case "${1}" in
    --file|-f)
      proxy_file=${2}
      shift
      ;;
    --help|-h)
      PrintHelp
      ;;
    *)
      PrintError "Invalid argument. $1"
  esac
  shift
done

proxy=""
if [ -f "${proxy_file}" ]; then
    http_proxy=$(awk -F "=" '/http_proxy/ {print $2}' $proxy_file)
    https_proxy=$(awk -F "=" '/https_proxy/ {print $2}' $proxy_file)
    no_proxy=$(awk -F "=" '/no_proxy/ {print $2}' $proxy_file)

    proxy="http_proxy=${http_proxy} https_proxy=${https_proxy} no_proxy=${no_proxy}"
    echo "$proxy"
else
    PrintError "No proxy data available to be setup. Missing --file parameter."
fi
