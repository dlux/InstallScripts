#!/bin/bash

# ====================================================
# This script creates a proxy environment variable.
# The intention is to reuse this parameter as entry in other installation scripts
# without affecting the system.
# Optionally setups proxy values on the system.
# ====================================================

# Uncomment the following line to debug this script
# set -o xtrace

while [[ ${1} ]]; do
  case "${1}" in
    --file|-f)
      proxy_file=${2}
      shift
      ;;
    --help|-h)
      echo " "
      echo "Script creates a proxy environment variable to be used as input in other installation scripts."
      echo "Script does not affect current system proxy variables."
      echo " "
      echo "Usage:"
      echo "     get_proxy [--file | -f] <filePath>"
      echo " "
      echo "     --file <filePath>     Pass the full file name where proxy information lives. See proxyrc.sample to see file sintaxis."
      echo "     -f     <filePath>     Pass the full file name where proxy information lives. See proxyrc.sample to see file sintaxis."
      echo "     --help                Prints current help text. "
      echo " "
      exit 1
      ;;
    *)
      echo "***************************" >&2
      echo "* Error: Invalid argument. $1" >&2
      echo "***************************" >&2
      exit 1
  esac
  shift
done

# proxy_file="/root/shared/proxyrc"
# "Getting proxy information from $proxy_file"
proxy=""
if [ -f "${proxy_file}" ]; then
    http_proxy=$(awk -F "=" '/http_proxy/ {print $2}' $proxy_file)
    https_proxy=$(awk -F "=" '/https_proxy/ {print $2}' $proxy_file)
    no_proxy=$(awk -F "=" '/no_proxy/ {print $2}' $proxy_file)

    proxy="http_proxy=${http_proxy} https_proxy=${https_proxy} no_proxy=${no_proxy}"
    #export $proxy
    echo "Variable proxy was setup to $proxy"
else
    echo "No proxy data available to be setup. Missing --file parameter."
fi
