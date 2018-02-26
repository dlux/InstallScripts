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
dluxPath='https://raw.githubusercontent.com/dlux/InstallScripts/master'
[[ ! -f common_packages ]] && curl -O $dluxPath/common_functions -O $dluxPath/common_packages
[[ ! -f common_packages ]] && exit 1
source common_packages

EnsureRoot
SetLocale /root
umask 022

PY3=False
_ANSIBLE=False
_KEYPAIR=False

# ======================= Processes installation options =====================
# Handle file sent as parameter - from where proxy info will be retrieved.
while [[ ${1} ]]; do
  case "${1}" in
    --help|-h)
      PrintHelp "Install devtools" $(basename "$0") \
          ("     --py3             To setup Python3."
          "     --ansible         To install ansible 2.0"
          "     --keypair             To create id_rsa keypair.")
      ;;
    --py3)
      PY3=True
      ;;
    --ansible)
      _ANSIBLE=True
      ;;
    --keypair)
      _KEYPAIR=True
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

echo "<<--------------- Update Package Manager ------------------------------"
UpdatePackageManager
[[ $_PACKAGE_MANAGER == 'yum' ]] && $_INSTALLER_CMD redhat-lsb-core
[[ $_PACKAGE_MANAGER == 'zypper' || $_PACKAGE_MANAGER == 'apt' ]] && $_INSTALLER_CMD lsb-release

# Setup user calling this script (non-root)
caller_user=$(who -m | awk '{print $1;}')
if [ -z $caller_user ]; then
    # For ubuntuOS except trusty use 'ubuntu'
    # Any other OS or trustyUbuntu-12.04 use 'vagrant'
    [[ $(IsUbuntu) == True && $(IsTrusty) != True ]] && caller_user='ubuntu' || caller_user='vagrant'
fi

echo "<<--------------- Install development libraries -----------------------"
$_INSTALLER_CMD curl git vim
if [[ $(IsUbuntu) == True ]]; then
    apt-get install -y build-essential libssl-dev libffi-dev libxml2-dev \
                   libxslt1-dev libpq-dev
else
   yum clean all
   yum groupinstall -y "Development Tools"
fi

$_INSTALLER_CMD htop
[ $_KEYPAIR == True ] && SetKeyPair $caller_user
[ $_ANSIBLE == True ] && echo "<<--- Install Ansible ---" && InstallAnsible

# By default install and configure Python 2.7 unless PY3 flag is setup
echo "<<--------------- Install python (2|3) --------------------------------"
if [ $PY3 == False ]; then
    echo 'Setting up PY2.x'
    [[ $(IsUbuntu) == True ]] && pck='python-dev' || pck='python-devel'
    $_INSTALLER_CMD python $pck
    # Install pip
    curl -Lo- https://bootstrap.pypa.io/get-pip.py | python
    pip install --upgrade pip
    pip install git-review virtualenv
else
# USE Python 3.x
    echo 'Setting up PY3.x'
    [[ $(IsUbuntu) == True ]] && pck='python3-dev' || pck='python3-devel.x86_64'
    $_INSTALLER_CMD python3 $pck
    curl -Lo- https://bootstrap.pypa.io/get-pip.py | python3
    pip3 install --upgrade pip3
    pip3 install git-review virtualenv
fi

echo "<<--------------- Configure git and user settings ---------------------"
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

curl -O https://raw.githubusercontent.com/dlux/InstallScripts/master/.vimrc
chown $caller_user:$caller_user .vimrc

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

    # Lastly unset proxy
    UnsetProxy "${_ORIGINAL_PROXY}"
fi

echo 'Script Finished.'
