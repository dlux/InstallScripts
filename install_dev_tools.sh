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


# ============================= Processes devstack installation options ============================
# Error Function
function PrintError {
    echo "************************" >&2
    echo "* ERROR: $1" >&2
    echo "************************" >&2
    exit 1
}
function PrintHelp {
    echo " "
    echo "Script installs basic development packages. Optionally uses given proxy"
    echo " "
    echo "Usage:"
    echo "./install_dev_tools.sh [<--proxy | -x> <http://proxyserver:port>]"
    echo " "
    echo "     --proxy | -x     Uses the given proxy server to install the tools."
    echo "     --help                Prints current help text. "
    echo " "
    exit 1
}


# Handle file sent as parameter - from where proxy info will be retrieved.
while [[ ${1} ]]; do
  case "${1}" in
    --proxy|-x)
      if [[ -z "${2}" || "${2}" == -* ]]; then
          PrintError "Missing proxy data."
      else
          _original_proxy="${2}"
          sudo bash -c "echo 'Acquire::http::Proxy \"${2}\";' >>  /etc/apt/apt.conf"
          sudo bash -c "echo 'Acquire::https::Proxy \"${2}\";' >>  /etc/apt/apt.conf"
          _proxy="http_proxy=${2} https_proxy=${2} no_proxy=127.0.0.1,localhost"
          _proxy="$_proxy HTTP_PROXY=${2} HTTPS_PROXY=${2} NO_PROXY=127.0.0.1,localhost"
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
sudo bash -c "eval $_proxy apt-get -y update"
# Install curl, git, pip, git-review, virtualenv and virtualenvwrapper
sudo bash -c "eval $_proxy apt-get -y install curl"
sudo bash -c "eval $_proxy apt-get -y install git"
eval $_proxy curl -Lo- https://bootstrap.pypa.io/get-pip.py | sudo bash -c "eval $proxy python"
eval $_proxy pip install git-review
eval $_proxy pip install virtualenv
eval $_proxy pip install virtualenvwrapper

# Install development tools
sudo bash -c "eval $proxy apt-get install --yes --force-yes build-essential libssl-dev libffi-dev python-dev libxml2-dev libxslt1-dev libpq-dev"

# Setup virtualenvwrapper
cat <<EOF >> "/$HOME/.bashrc"
export WORKON_HOME=$HOME/.virtualenvs
source /usr/local/bin/virtualenvwrapper.sh
EOF

# Configure git & git-review
#-----------------------------
git config --global user.name "Luz Cazares"
git config --global user.email "luz.cazares"
git config --global gitreview.username "dlux"

# If behind proxy, use http instead of git
#if [[ ! -z $_proxy ]]; then
#    git config --global url.https://.insteadOf git://
#    git config --global gitreview.scheme https
#    git config --global gitreview.port 443
#fi

# Cleanup _proxy from apt if added
if [[ ! -z "${_original_proxy}" ]]; then
  scaped_str=$(echo $_original_proxy | sed -s 's/[\/&]/\\&/g')
  sed -i "/$scaped_str/c\\" /etc/apt/apt.conf
fi
