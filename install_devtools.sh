#!/bin/bash

# ============================================================================
# Script installs dev tools:
# pip, git, git-review, virtualenv, virtualenvwrapper,
# build-essential among others
# ============================================================================

# Uncomment the following line to debug this script
# set -o xtrace

#=============================================================================
# GLOBAL FUNCTIONS
#=============================================================================

[[ ! -f common_functions ]] curl -O https://raw.githubusercontent.com/dlux/InstallScripts/master/common_functions
source common_functions

EnsureRoot
SetLocale /root

# ======================= Processes installation options =====================
# Handle file sent as parameter - from where proxy info will be retrieved.
while [[ ${1} ]]; do
  case "${1}" in
    --help|-h)
      PrintHelp "Install devtools" $(basename "$0")
      ;;
    *)
      HandleOptions "$@"
      shift
  esac
  shift
done

# ============================================================================
# BEGIN PACKAGE INSTALATATION
eval $_PROXY apt-get -y update
eval $_PROXY apt-get install -y curl git
eval $_PROXY curl -Lo- https://bootstrap.pypa.io/get-pip.py | eval $_PROXY python
eval $_PROXY pip install git-review
eval $_PROXY pip install virtualenv
eval $_PROXY pip install virtualenvwrapper

# Install development tools
eval $_PROXY apt-get install -y build-essential libssl-dev libffi-dev \
python-dev libxml2-dev libxslt1-dev libpq-dev

# Install py3 if it is xenial
# TODO in future remove support for trusty and prepare for xenial and up
if [[ $(IsXenial) == True ]]; then
  eval $_PROXY apt-get install -y python3-dev
  # Fix pip and virtualenv pyhton versions
  eval $_PROXY curl -Lo- https://bootstrap.pypa.io/get-pip.py | eval $_PROXY python3 -v
  eval $_PROXY pip install --upgrade virtualenv
fi

# Setup user calling this script (non-root)
caller_user=$(who -m | awk '{print $1;}')
if [ -z $caller_user ]; then
  [[ $(IsTrusty) == True ]] && caller_user='vagrant' || caller_user='ubuntu'
fi
caller_home="/home/$caller_user"
echo $caller_home

if [ ! -d "$caller_home/.virtualenvs" ]; then
    mkdir "$caller_home/.virtualenvs"
    chown $caller_user:$caller_user "$caller_home/.virtualenvs"
fi

if [ ! -f "$caller_home/.bashrc" ]; then
    cp /etc/skel/.bashrc "$caller_home/.bashrc"
    chown $caller_user:$caller_user "$caller_home/.bashrc"
fi

cat <<EOF >> "$caller_home/.bashrc"
export WORKON_HOME=$caller_home/.virtualenvs
source /usr/local/bin/virtualenvwrapper.sh
EOF

# Configure git & git-review
#-----------------------------
sudo -H -u $caller_user bash -c 'git config --global user.name "Luz Cazares"'
sudo -H -u $caller_user bash -c 'git config --global user.email "luz.cazares"'
sudo -H -u $caller_user bash -c 'git config --global gitreview.username "luzcazares"'

# If behind proxy create .ssh/config file to bypass proxy
if [[ ! -z "${_ORIGINAL_PROXY}" ]]; then
  prx=$(echo "${_ORIGINAL_PROXY}" | awk -F '//' '{print $2}' | awk -F ':' '{print $1}')
  echo "Host *" >> "$caller_home"/.ssh/config
  echo "ProxyCommand nc -X 5 -x $prx:1080 %h %p" >> "$caller_home"/.ssh/config
fi
# When using proxy, other method is to use http instead of git/ssh for the connection
#if [[ ! -z $_PROXY ]]; then
#    git config --global url.https://.insteadOf git://
#    git config --global gitreview.scheme https
#    git config --global gitreview.port 443
#fi

# Cleanup _proxy from apt if added - first coincedence
UnsetProxy

