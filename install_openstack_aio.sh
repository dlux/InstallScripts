#!/bin/bash

# ==============================================================================
# Script installs openstack-ansible all-in-one.
# ==============================================================================

# Uncomment the following line to debug this script
set -o xtrace

#=================================================
# GLOBAL VARIABLES DEFINITION
#=================================================
_original_proxy=''
_proxy=''
_domain=',.intel.com'
_branch='master'
_apply_security_hardening=false

#=================================================
# GLOBAL FUNCTIONS
#=================================================
# Error Function
function PrintError {
    echo "************************" >&2
    echo "* $(date +"%F %T.%N") ERROR: $1" >&2
    echo "************************" >&2
    exit 1
}

function PrintHelp {
    echo " "
    echo "Script installs openstack ansible all-in-one. Optionally uses given proxy"
    echo " "
    echo "Usage:"
    echo "./install_openstack_aio.sh [--branch | -b master] [--proxy | -x <http://proxyserver:port>]"
    echo " "
    echo "     --branch | -b     Uses the given branch name to deploy openstack-ansible aio. Defaults to master."
    echo "     --proxy  | -x     Uses the given proxy server to install the tools."
    echo "     --harden | -s     Makes deployment install security hardening."
    echo "     --help            Prints current help text. "
    echo " "
    exit 1
}

# Ensure script is run as root
if [ "$EUID" -ne "0" ]; then
  PrintError "This script must be run as root."
fi

# Set locale
locale-gen en_US
update-locale
export HOME=/root

# ============================= Processes openstack-ansible installation options ============================
# Handle file sent as parameter - from where proxy info will be retrieved.
while [[ ${1} ]]; do
  case "${1}" in
    --branch|-b)
      if [[ -z "${2}" || "${2}" == -* ]]; then
          PrintError "Missing openstack-ansible branch to deploy."
      else
          _branch="${2}"
      fi
      shift
      ;;
    --proxy|-x)
      if [[ -z "${2}" || "${2}" == -* ]]; then
          PrintError "Missing proxy data."
      else
          _original_proxy="${2}"
          if [ -f /etc/apt/apt.conf ]; then
              echo "Acquire::http::Proxy \"${2}\";" >>  /etc/apt/apt.conf
          elif [ -d /etc/apt/apt.conf.d ]; then
              echo "Acquire::http::Proxy \"${2}\";" >>  /etc/apt/apt.conf.d/70proxy.conf
          fi
          npx="127.0.0.0/8,localhost,10.0.0.0/8,192.168.0.0/16${_domain}"
          _proxy="http_proxy=${2} https_proxy=${2} no_proxy=${npx}"
          _proxy="$_proxy HTTP_PROXY=${2} HTTPS_PROXY=${2} NO_PROXY=${npx}"
      fi
      shift
      ;;
    --harden|-s)
      _apply_security_hardening=true
      ;;
    --help|-h)
      PrintHelp
      ;;
    *)
      PrintError "Invalid Argument."
  esac
  shift
done

# ============================================================================================
# ISTALL PRE-REQUISITES

eval $_proxy apt-get -y -qq update
eval $_proxy apt-get -y -qq install wget
eval $_proxy wget -qO- https://raw.githubusercontent.com/dlux/InstallScripts/master/install_devtools.sh | eval $_proxy sh

eval $_proxy git clone https://github.com/openstack/openstack-ansible.git -b $_branch /opt/openstack-ansible

cd /opt/openstack-ansible

# ============================================================================================
# INSTALL OPENSTACK-ANSIBLE AIO

export apply_security_hardening=$_apply_security_hardening
eval $_proxy sh scripts/bootstrap-ansible.sh
eval $_proxy sh scripts/bootstrap-aio.sh
eval $_proxy sh scripts/run-playbooks.sh

cd playbooks/
eval $_proxy openstack-ansible os-tempest-install.yml

# Cleanup _proxy from apt if added - first coincedence
if [[ ! -z "${_original_proxy}" ]]; then
  scaped_str=$(echo $_original_proxy | sed -s 's/[\/&]/\\&/g')
  if [ -f /etc/apt/apt.conf ]; then
      sed -i "0,/$scaped_str/{/$scaped_str/d;}" /etc/apt/apt.conf
  elif [ -d /etc/apt/apt.conf.d ]; then
      sed -i "0,/$scaped_str/{/$scaped_str/d;}" /etc/apt/apt.conf.d/70proxy.conf
  fi
fi
