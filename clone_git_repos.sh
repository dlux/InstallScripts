#!/bin/bash
#=======================================
# Install a bunch of git repositories
# Asume git and git review are installed
#=======================================

# Clone my common OpenStack projects
repo_list=(
  'https://github.com/openstack/interop.git'
  'https://github.com/openstack/refstack.git'
  'https://github.com/openstack/refstack-client.git'
  'https://github.com/openstack/tempest.git'
  'https://github.com/openstack/openstack-ansible.git'
  'https://github.com/openstack/openstack-ansible-os_tempest.git'
  'https://github.com/openstack-infra/project-config.git'
  'https://github.com/dlux/InstallScripts.git'
)

for i in "${repo_list[@]}"; do
    name=$(echo "${i}" | sed 's/.*openstack\///g' | sed 's/.git//g')

    if [[ -d ${name} ]]; then
       _date=$(date +"%m-%d-%y%T")
       mv "${name}" "${name}_old_${_date}"
    fi

    git clone "${i}"
    pushd "${name}"
    git review -s
    popd
done
