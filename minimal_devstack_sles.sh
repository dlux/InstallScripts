#!/bin/bash
# set -o xtrace

source common_functions

_PROXY=''
if [ -n "${http_proxy}" ];then
    npx="127.0.0.1,localhost,10.0.0.0/8,192.168.0.0/16,.intel.com"
    _PROXY="http_proxy=${http_proxy} https_proxy=${http_proxy} no_proxy=${npx}"
    _PROXY="$_PROXY HTTP_PROXY=${http_proxy} HTTPS_PROXY=${http_proxy} NO_PROXY=${npx}"
fi

_DEST=/opt/stack/devstack
_PASSWORD="secure123"
_TOKEN=$(openssl rand -hex 10)
STACK_USER="${STACK_USER:-ad_lcazares}"
STACK_GROUP="${STACK_GROUP:-intelall}"
export FORCE="yes"

if [[ $(id -u "${STACK_USER}" > /dev/null 2>&1; echo $?) -eq 1 ]]; then
    PrintError "Export existing non-root STACK_USER before running the script."
fi

# Make sure using root user
if [ "$EUID" -ne "0" ]; then
     PrintError "This script must be run as root."
fi

umask 022

eval $_PROXY zypper ref
eval $_PROXY zypper install lsb-release
eval $_PROXY zypper install -y git sudo 

if [ ! -d $_DEST ]; then
  eval $_PROXY git clone https://git.openstack.org/openstack-dev/devstack $_DEST
fi
cd $_DEST

if [ ! -f local.conf ]; then
  cat <<EOL >local.conf
[[local|localrc]]
HOST_IP=$(ip route get 8.8.8.8 | awk '{ print $NF; exit }')
ADMIN_PASSWORD=${_PASSWORD}
DATABASE_PASSWORD=${_PASSWORD}
RABBIT_PASSWORD=${_PASSWORD}
SERVICE_PASSWORD=${_PASSWORD}
SERVICE_TOKEN=${_TOKEN}
ENABLE_DEBUG_LOG_LEVEL=False
DATA_DIR=/home/${STACK_USER}/data
# Use https
GIT_BASE=https://git.openstack.org
USE_PYTHON3=True
PYTHON3_VERSION=3
LOGDIR=/tmp/logs
REQUIREMENTS_DIR=/home/${STACK_USER}/requirements
SERVICE_DIR=/tmp/status
EOL
fi

chown -R ${STACK_USER}:${STACK_GROUP} $_DEST

eval $_PROXY su $STACK_USER -c "./stack.sh"

