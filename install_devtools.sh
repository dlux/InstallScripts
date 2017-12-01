#!/bin/bash

# ============================================================================
# Script installs dev tools:
# pip, git, git-review, virtualenv, build-essential among others
# ============================================================================

# Uncomment the following line to debug this script
set -o xtrace

#=============================================================================
# GLOBAL FUNCTIONS
#=============================================================================

[[ ! -f common_functions ]] && curl -O \
  https://raw.githubusercontent.com/dlux/InstallScripts/master/common_functions
[[ ! -f common_functions ]] && exit 1
source common_functions

EnsureRoot
SetLocale /root
umask 022

PY3=False

# ======================= Processes installation options =====================
# Handle file sent as parameter - from where proxy info will be retrieved.
while [[ ${1} ]]; do
  case "${1}" in
    --help|-h)
      PrintHelp "Install devtools" $(basename "$0") \
          "     --py3             To setup Python3."
      ;;
    --py3)
      PY3=True
      ;;
    *)
      HandleOptions "$@"
      shift
  esac
  shift
done

# ============================================================================
# BEGIN PACKAGE INSTALATATION
# If proxy passed as parameter - set it on the environment
[[ -n $_PROXY ]] && source ".PROXY"

apt-get -y update

# Setup user calling this script (non-root)
caller_user=$(who -m | awk '{print $1;}')
if [ -z $caller_user ]; then
    [[ $(IsTrusty) == True ]] && caller_user='vagrant' || caller_user='ubuntu'
fi

apt-get install -y curl git
apt-get install -y build-essential libssl-dev libffi-dev libxml2-dev \
                   libxslt1-dev libpq-dev python-dev

#curl -Lo- https://bootstrap.pypa.io/get-pip.py | python
apt-get install -y python-pip
pip install --upgrade pip
pip install git-review virtualenv

if [[ $(IsXenial) == True && $PY3 == True ]]; then
    echo 'Setting up PY3'
    apt-get install -y python3-dev python3-pip
    pip3 install --upgrade pip3
    pip3 install git-review virtualenv
fi

if [ ! -f "/home/$caller_user/.bashrc" ]; then
    cp /etc/skel/.bashrc "/home/$caller_user/.bashrc"
    chown $caller_user:$caller_user "/home/$caller_user/.bashrc"
fi

echo 'Configuring git & git-review'
cmd='git config --global'
sudo -H -u $caller_user bash -c "$cmd user.name 'Luz Cazares'"
sudo -H -u $caller_user bash -c "$cmd user.email 'luz.cazares@intel.com'"
sudo -H -u $caller_user bash -c "$cmd core.editor 'vim'"
sudo -H -u $caller_user bash -c "$cmd gitreview.username 'luzcazares'"

# Bypass proxy on ssh (used by git) via .ssh/config file.
if [[ ! -z "${_ORIGINAL_PROXY}" ]]; then
    echo 'Setting proxy on .ssh/config'
    pxSvr=$(echo "${_ORIGINAL_PROXY}" | awk -F '//' '{print $2}' \
            | awk -F ':' '{print $1}')
    cfgFile="/home/$caller_user/.ssh/config"
    mkdir -p "/home/$caller_user/.ssh"
    echo "Host *" >> "${cfgFile}"
    echo "ProxyCommand nc -X 5 -x $pxSvr:1080 %h %p" >> "${cfgFile}"
    chown $caller_user:$caller_user "${cfgFile}"
fi

# Cleanup _proxy from apt if added - first coincedence
UnsetProxy "${_ORIGINAL_PROXY}"

