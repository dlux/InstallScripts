#!/bin/bash
# ==========================================================
# Script installs: devstack
# Devstack options:
#    --minimal: installs devstack with minimal configuration
#    --branch: installs devstack for a specific branch e.g stable/kilo
#    --ceph: installs devstack with ceph as backend
#    --neutron: installs devstack with neutron instead of nova-net
#    --repo: (TobeImplemented) installs devstack packages from given repo(not OpenStack)
# Configuration uses: MariaDB, RabbitMQ, master branch, and reset default passwords to secure123.
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
_ceph_lines=''
_neutron_lines=''

#=================================================
# Ensure script is run as root
#=================================================
if [ "$EUID" -ne "0" ]; then
  echo "$(date +"%F %T.%N") ERROR : This script must be run as root." >&2
  exit 1
fi

# ============================= Processes devstack installation options ============================
function PrintHelp {
    echo " "
    echo "Script installs devstack - different configurations available."
    echo " "
    echo "Usage:"
    echo "     ./install_devstack [--minimal|--ceph|--neutron|--branch]"
    echo " "
    echo "     --minimal      Installs devstack with minimal configuration."
    echo "     --branch       Use the given devstack branch e.g stable/liberty."
    echo "     --ceph         Configure devstack with ceph cluster."
    echo "     --neutron      Configure devstack with neutron instead of nova-net."
    echo "     --repo         (TobeImplemented)Installs devstack packages from given repo(s)."
    echo "     --password     Use given password for devstack DBs,Queue, etc."
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
    --minimal)
      # minimal installation hence no extra stuff
      shift
      ;;
    --branch)
      # Installs a specific branch
      if [ -z "${2}" ]; then
        PrintError "Missing branch name."
      else
        _branch="${2}"
      fi
      shift
      ;;
    --ceph)
      read -r -d '' _ceph_lines << EOM
#
# CEPH
#  -------
enable_plugin ceph https://github.com/openstack/devstack-plugin-ceph
EOM
      shift
      ;;
   --neutron)
      read -r -d '' _neutron_lines << EOM
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
      shift
      ;;
    --repo)
      # TODO configuration to be implemented
      echo "--repo is under development :("
      shift
      ;;
    --password)
      # Use specific password for common objetcs
      if [ -z "${2}" ]; then
        PrintError "Missing password."
      else
        _password="${2}"
      fi
      shift
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
# Set locale
locale-gen en_US
update-locale
export HOME=/root

# Use proxy if needed
proxy=""
# Ubuntu
# echo "Acquire::http::Proxy \"${proxy}\";" >>  /etc/apt/apt.conf
# echo "Acquire::https::Proxy \"${proxy}\";" >>  /etc/apt/apt.conf

# Install software pre-requisites
#   Install git
eval $proxy apt-get -y --force-yes install  git

#   Install pip
eval $proxy apt-get -y --force-yes install  python-pip


#=================================================
# BASIC DEVSTACK
#=================================================

# Create stack user
eval $proxy curl -Lo- https://raw.githubusercontent.com/openstack-dev/devstack/$_branch/tools/create-stack-user.sh | bash
callerUser='stack'
export STACK_USER=$callerUser

# Clone devstack project with correct branch
sudo -u $callerUser -H sh -c "eval $proxy git clone https://git.openstack.org/openstack-dev/devstack -b $_branch devstack"

cd devstack

# Create local.conf file
sudo -u $callerUser -H sh -c "cp ./samples/local.conf local.conf"

# Modify local.conf with minimal configuration.
# Pre-set the passwords to prevent interactive prompts
read -r -d '' password_lines << EOM
ADMIN_PASSWORD="${_password}"
MYSQL_PASSWORD="${_password}"
RABBIT_PASSWORD="${_password}"
SERVICE_PASSWORD="${_password"}
EOM

sed -i '/PASSWORD/c\' ./local.conf
echo "$password_lines" >> ./local.conf
# Log OpenStack services output (beside screen output write it to file)
#sed -i '/LOGDAYS/ a LOGDIR=$DEST/logs/services' ./local.conf

# Aditional Configuration
if [[ ! -z "$_neutron_lines" ]]; then
    echo "$_neutron_lines" >> ./local.conf
fi
if [[ ! -z "$_ceph_lines" ]]; then
    echo "$_ceph_lines" >> ./local.conf
fi

# Enable tempest if not already enabled
sed -i '/tempest/c\' ./local.conf
echo "# Install the tempest test suite" >> ./local.conf
echo "enable_service tempest" >> ./local.conf

# Run install command
sudo -u $callerUser -H sh -c "./stack.sh"
