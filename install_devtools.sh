#!/bin/bash

# ==============================================================================
# Script installs dev tools:
# pip, git, git-review, virtualenv, virtualenvwrapper, build-essential among others
# ==============================================================================

# Uncomment the following line to debug this script
# set -o xtrace

#=================================================
# GLOBAL VARIABLES DEFINITION
#=================================================
_original_proxy=''
_proxy=''
_domain=',.intel.com'

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
    echo "Script installs basic development packages. Optionally uses given proxy"
    echo " "
    echo "Usage:"
    echo "./install_dev_tools.sh [--proxy | -x <http://proxyserver:port>]"
    echo " "
    echo "     --proxy | -x     Uses the given proxy server to install the tools."
    echo "     --help           Prints current help text. "
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

# ============================= Processes devstack installation options ============================
# Handle file sent as parameter - from where proxy info will be retrieved.
while [[ ${1} ]]; do
  case "${1}" in
    --proxy|-x)
      if [[ -z "${2}" || "${2}" == -* ]]; then
          PrintError "Missing proxy data."
      else
          _original_proxy="${2}"
          echo "Acquire::http::proxy \"${2}\";" >>  /etc/apt/apt.conf
          npx="127.0.0.0/8,localhost,10.0.0.0/8,192.168.0.0/16${_domain}"
          _proxy="http_proxy=${2} https_proxy=${2} no_proxy=${npx}"
          _proxy="$_proxy HTTP_PROXY=${2} HTTPS_PROXY=${2} NO_PROXY=${npx}"
      fi
      shift
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
# BEGIN PACKAGE INSTALATATION
eval $_proxy apt-get -y update
eval $_proxy apt-get install -y curl git
eval $_proxy curl -Lo- https://bootstrap.pypa.io/get-pip.py | eval $_proxy python
eval $_proxy pip install git-review
eval $_proxy pip install virtualenv
eval $_proxy pip install virtualenvwrapper

# Install development tools
eval $proxy apt-get install -y --force-yes build-essential libssl-dev libffi-dev python-dev libxml2-dev libxslt1-dev libpq-dev

# Setup virtualenvwrapper
caller_user=$(who -m | awk '{print $1;}')
caller_user=${caller_user:-'vagrant'}
caller_home="/home/$caller_user"

cat <<EOF >> "$caller_home/.bashrc"
export WORKON_HOME=$caller_home/.virtualenvs
source /usr/local/bin/virtualenvwrapper.sh
EOF

# Configure git & git-review
#-----------------------------
git config --global user.name "Luz Cazares"
git config --global user.email "luz.cazares"
git config --global gitreview.username "luzcazares"

# If behind proxy, use http instead of git
# Is better to set ssh proxy via .ssh/config file

#if [[ ! -z $_proxy ]]; then
#    git config --global url.https://.insteadOf git://
#    git config --global gitreview.scheme https
#    git config --global gitreview.port 443
#fi

# Cleanup _proxy from apt if added - first coincedence
if [[ ! -z "${_original_proxy}" ]]; then
  scaped_str=$(echo $_original_proxy | sed -s 's/[\/&]/\\&/g')
  sed -i "0,/$scaped_str/{/$scaped_str/d;}" /etc/apt/apt.conf
fi
