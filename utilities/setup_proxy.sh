#!/bin/bash

# ==============================================================================
# This script reads proxy information from a given file.
# Setups proxies on the system - Ubuntu/CentOS.
#
# Additonal proxy file sintaxis look at proxyrc.sample
# ==============================================================================

# Uncomment the following line to debug this script
# set -o xtrace

# Handle file sent as parameter - from where proxy info will be retrieved.
while [[ ${1} ]]; do
  case "${1}" in
    --file|-f)
      proxy_file=${2}
      shift
      ;;
    --help|-h)
      echo " "
      echo "Script reads proxy information from a given file."
      echo "Setups proxies on the system - Ubuntu/CentOS."
      echo " "
      echo "Usage:"
      echo "     setup_proxy [--file | -f] <filePath>"
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

# Ensure script is run as root
if [ "$EUID" -ne "0" ]; then
  echo "$(date +"%F %T.%N") ERROR : This script must be run as root." >&2
  exit 1
fi

# proxy_file="/root/shared/proxyrc"
echo "Setting proxy information from $proxy_file "

if [ -f "${proxy_file}" ]; then
  source $proxy_file

  # Ubuntu
  if [ -f /etc/apt/apt.conf ]
  then
    echo "Ubuntu system - Acquiring proxy."
    echo "Acquire::http::Proxy \"${http_proxy}\";" >>  /etc/apt/apt.conf
    echo "Acquire::https::Proxy \"${https_proxy}\";" >>  /etc/apt/apt.conf
  fi

  if [ -d /etc/apt/apt.conf.d ]
  then
    echo "Ubuntu system - Acquiring proxy."
    echo "Acquire::http::Proxy \"${http_proxy}\";" >>  /etc/apt/apt.conf.d/70proxy.conf
    echo "Acquire::https::Proxy \"${https_proxy}\";" >>  /etc/apt/apt.conf.d/70proxy.conf
  fi

  # CentOS
  if [ -f /etc/yum.conf ]
  then
    echo "CentOS system - Acquiring proxy."
    echo "proxy=${http_proxy}" >> /etc/yum.conf
  fi

  # Interactive shell
  if [ -f /etc/bashrc ]
  then
    echo "Modifying interactive shell."
    echo "export http_proxy=${http_proxy}" >> /etc/bashrc
    echo "export https_proxy=${https_proxy}" >> /etc/bashrc
    echo "export no_proxy=${no_proxy}" >> /etc/bashrc
  fi

  # Interactive shell - all users
  if [ -f /etc/bash.bashrc ]
  then
    echo "Modifying interactive shell."
    echo "export http_proxy=${http_proxy}" >> /etc/bash.bashrc
    echo "export https_proxy=${https_proxy}" >> /etc/bash.bashrc
    echo "export no_proxy=${no_proxy}" >> /etc/bash.bashrc
  fi

  echo "http_proxy=${http_proxy}" >> /etc/wgetrc
  echo "https_proxy=${https_proxy}" >> /etc/wgetrc
else
  # 0. Workaround for vagrant boxes
  sed -i "s/10.0.2.3/8.8.8.8/g" /etc/resolv.conf
fi

