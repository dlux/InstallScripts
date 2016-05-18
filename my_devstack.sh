#!/bin/bash
# ==========================================================
# Script installs: devstaick
# Assume Ubuntu 14.04 or higher
# See help to display all the options.
# Devstack configuration:: MariaDB, RabbitMQ, master branch, and reset default passwords to secure123.
# =========================================================

# Uncomment the following line to debug
# set -o xtrace

#=================================================
# GLOBAL VARIABLES DEFINITION
#=================================================
# release branch
# branch='stable/liberty'
_branch="master"
# openstack component password
_password='secure123'

# Additional configurations
_added_lines=''

# Proxy to use for the installation
_proxy=''

# ============================= Processes devstack installation options ============================
function PrintHelp {
    echo " "
    echo "Script installs devstack - different configurations available."
    echo " "
    echo "Usage:"
    echo "     ./install_devstack [--basic|--branch <branch>|--ceph|--heat|--neutron|--password <pwd>|--swift|--proxy <http://<proxy-server>:<port>|--help]"
    echo " "
    echo "     --basic        Installs devstack with minimal configuration."
    echo "     --branch       Use given branch for installation e.g stable/liberty."
    echo "     --ceph         Configure devstack with ceph cluster."
    echo "     --heat         Add heat project."
    echo "     --neutron      Configures neutron instead of nova-net."
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
   --neutron)
      read -r -d '' lines << EOM
#
# NEUTRON
#  -------
disable_service n-net
enable_service q-svc
enable_service q-agt
enable_service q-dhcp
enable_service q-l3
enable_service q-meta
enable_service neutron
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
        sudo bash -c "echo 'Acquire::http::Proxy \"${2}\";' >>  /etc/apt/apt.conf"
        sudo bash -c " echo 'Acquire::https::Proxy \"${2}\";' >>  /etc/apt/apt.conf"
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

# ====================================
# Begin Instalation and Configuration:
# ====================================
export STACK_USER=$(whoami)

# Install software pre-requisites
sudo -H sh -c "eval $_proxy apt-get update"
#   Install git
sudo -H sh -c "eval $_proxy apt-get -y install git"
#   Install pip
sudo -H sh -c "eval $_proxy apt-get -y install python-pip"

#=================================================
# BASIC DEVSTACK
#=================================================
# Clone devstack project with correct branch
eval $_proxy git clone https://git.openstack.org/openstack-dev/devstack -b $_branch devstack
cd devstack

# Create local.conf file
cp ./samples/local.conf local.conf

# Modify local.conf with minimal configuration.
# Pre-set the passwords to prevent interactive prompts
read -r -d '' password_lines << EOM
ADMIN_PASSWORD="${_password}"
MYSQL_PASSWORD="${_password}"
RABBIT_PASSWORD="${_password}"
SERVICE_PASSWORD="${_password}"
EOM

sed -i '/PASSWORD/c\' ./local.conf
echo "$password_lines" >> ./local.conf
# Log OpenStack services output (beside screen output write it to file)
#sed -i '/LOGDAYS/ a LOGDIR=$DEST/logs/services' ./local.conf

# Aditional Configuration
if [[ ! -z "$_added_lines" ]]; then
    echo "$_added_lines" >> ./local.conf
fi

# Enable tempest if not already enabled
sed -i '/tempest/c\' ./local.conf
echo "# Install the tempest test suite" >> ./local.conf
echo "enable_service tempest" >> ./local.conf

# Configure git to use https instead of git
git config --global url."https://".insteadOf git://

# Run Devstack install command [stack.sh]
export $_proxy
eval $_proxy ./stack.sh

# Clean up _proxy from apt if added
if [[ ! -z "${_original_proxy}" ]]; then
  scaped_str=$(echo $_original_proxy | sed -s 's/[\/&]/\\&/g')
  sudo -H sh -c "sed -i '/$scaped_str/c\\' /etc/apt/apt.conf"
fi

