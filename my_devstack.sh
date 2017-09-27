#!/bin/bash
# ==========================================================
# Script installs: devstaick
# Assume Ubuntu 16.04, ubuntu user available.
# See help to display all the options.
# Devstack configuration:: MariaDB, RabbitMQ, master branch,
#                          default passwords to secure123.
# =========================================================

# Uncomment the following line to debug
# set -o xtrace

#=================================================
# GLOBAL VARIABLES DEFINITION
#=================================================
# release branch
# branch='stable/liberty'
_branch="master"

_dest_path="/opt/stack/devstack"

# openstack component password
_password='secure123'

# Additional configurations
_added_lines=''

# Proxy to use for the installation
_proxy=''

# User for installation
STACK_USER='ubuntu'

_added_lines=''

# token
_token=`openssl rand -hex 10`

# ============================= Processes devstack installation options ============================
function PrintHelp {
    echo " "
    echo "Script installs devstack - different configurations available."
    echo " "
    echo "Usage:"
    echo "     ./install_devstack [--basic|--branch <branch>|--ceph|--heat|--password <pwd>|--swift|--proxy <http://<proxy-server>:<port>|--help]"
    echo " "
    echo "     --basic        Installs devstack with minimal configuration."
    echo "     --branch       Use given branch for installation e.g stable/liberty."
    echo "     --ceph         Configure devstack with ceph cluster."
    echo "     --heat         Add heat project."
    echo "     --password     Use given password for devstack DBs,Queue, etc."
    echo "     --proxy        Uses the given proxy for the full installation"
    echo "     --repo         (TobeImplemented)Installs devstack packages from given repo(s)."
    echo "     --swift        Add swift project."
    echo " "
    echo "     --help         Prints current help text. "
    echo " "
    exit 1
}
function PrintError {
    echo "***************************" >&2
    echo "* Error: $1" >&2
    echo "  See ./install_devstack --help" >&2
    echo "***************************" >&2
    exit 1
}

# If no parameter passed print help
if [ -z "${1}" ]; then
   PrintHelp
fi

while [[ ${1} ]]; do
  case "${1}" in
    --basic)
      # minimal installation hence no extra stuff
      shift
      ;;
    --branch)
      # Installs a specific branch
      if [[ -z "${2}" || "${2}" == --* ]]; then
        PrintError "Missing branch name."
      else
        _branch="${2}"
      fi
      shift
      ;;
    --ceph)
      read -r -d '' lines << EOM
#
# CEPH
#  -------
enable_plugin ceph https://github.com/openstack/devstack-plugin-ceph
EOM
      _added_lines="$_added_lines"$'\n'"$lines"
      ;;
    --heat)
      read -r -d '' lines << EOM
#
# HEAT
#
enable_service h-eng
enable_service h-api
enable_service h-api-cfn
enable_service h-api-cw
EOM
      _added_lines="$_added_lines"$'\n'"$lines"
      ;;
    --password)
      # Use specific password for common objetcs
      if [[ -z "${2}" || "${2}" == --* ]]; then
        PrintError "Missing password."
      else
        _password="${2}"
      fi
      shift
      ;;
    --proxy)
      # Install devstack with server behind proxy
      if [[ -z "${2}" || "${2}" == --* ]]; then
        PrintError "Missing proxy. Expected: http://<server>:<port>"
      else
        _original_proxy="${2}"
        echo "Acquire::http::Proxy \"${2}\";" >>  /etc/apt/apt.conf
        npx="127.0.0.1,localhost,10.0.0.0/8,192.168.0.0/16"
        _proxy="http_proxy=${2} https_proxy=${2} no_proxy=${npx}"
        _proxy="$_proxy HTTP_PROXY=${2} HTTPS_PROXY=${2} NO_PROXY=${npx}"
      fi
      shift
      ;;
    --repo)
      # TODO configuration to be implemented
      echo "--repo is under development :("
      ;;
    --swift)
      read -r -d '' lines << EOM
#
# SWIFT
#  -------
enable_service s-proxy s-object s-container s-account
EOM
      _added_lines="$_added_lines"$'\n'"$lines"
      ;;
    --help|-h)
      PrintHelp
      ;;
    *)
      PrintError "Invalid Argument: $1."
  esac
  shift
done

# ============================================================================================

# Make sure using root user
if [ "$EUID" -ne "0" ]; then
    PrintError "This script must be run as root."
fi

# ====================================
# Begin Instalation and Configuration:
# ====================================
# Install software pre-requisites
eval $_proxy apt-get update -y
#   Install git
eval $_proxy apt-get -y install sudo git
eval $_proxy curl -Lo- https://bootstrap.pypa.io/get-pip.py | eval $_proxy python3

#=================================================
# BASIC DEVSTACK
#=================================================
# Clone devstack project with correct branch
# Into path - defatult to /opt/stack/devstack
if [[ ! -d $_dest_path ]];then
    eval $_proxy git clone https://git.openstack.org/openstack-dev/devstack -b $_branch $_dest_path
fi

cd "$_dest_path"

# Create local.conf file
if [ ! -f local.conf ]; then
    token=$(openssl rand -hex 10)
    cat <<EOL >local.conf
[[local|localrc]]
HOST_IP=$(ip route get 8.8.8.8 | awk '{ print $NF; exit }')
ADMIN_PASSWORD=${_password}
DATABASE_PASSWORD=${_password}
RABBIT_PASSWORD=${_password}
SERVICE_PASSWORD=${_password}
SERVICE_TOKEN=${token}
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

    # Additional Projects Configuration
    echo "$_added_lines" >> local.conf

fi

# Configure git to use https instead of git
git config --global url."https://".insteadOf git://

# Run Devstack install command [stack.sh]
chown -R $STACK_USER:$STACK_USER $_dest_path
eval $_proxy su ubuntu -c "./stack.sh"

# Clean up _proxy from apt if added
if [[ ! -z "${_original_proxy}" ]]; then
  scaped_str=$(echo $_original_proxy | sed -s 's/[\/&]/\\&/g')
  sed -i "/$scaped_str/c\\" /etc/apt/apt.conf
fi

