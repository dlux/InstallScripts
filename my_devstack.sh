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

# Default user to install devstack
_caller_user=''

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
    echo "     ./install_devstack [--basic|--branch <branch>|--ceph|--heat|--neutron|--password <pwd>|--swift|--proxy <[http|https]://<proxy-server>:<port>|--help|--user <existingUserName>]"
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
    echo "     --user         The user to run devstack - must be different than root"
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
      if [ -z "${2}" ]; then
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
      if [ -z "${2}" ]; then
        PrintError "Missing password."
      else
        _password="${2}"
      fi
      shift
      ;;
    --proxy)
      # Install devstack with server behind proxy
      if [ -z "${2}" ]; then
        PrintError "Missing proxy. Expected: http://<server>:<port>"
      else
        _original_proxy="${2}"
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
    --user)
      # Install devstack with an existing user
      if [ -z "${2}" ]; then
        PrintError "Missing user name. Expected: existing user name other than root."
      else
        user_id="$(id -u ${2})"
        if [[ ! $user_id || $user_id -eq "0" ]]; then
          PrintError "User does not exist or is root. Expected: existing user name other than root"
        else
           _caller_user="${2}"
        fi
      fi
      shift
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

# if no user is provided try to get caller user
if [ -z "${_caller_user}" ]; then
    _caller_user=$(who -m | awk '{print $1;}')
    # Fail If still empty
    if [ -z $_caller_user ]; then
      PrintError "Provide a non root user"
    fi
fi
_caller_home="/home/$_caller_user"
export STACK_USER=$_caller_user

# Use proxy if provided
if [[ ! -z "${_original_proxy}" ]]; then
  echo "Acquire::http::Proxy \"${_original_proxy}\";" >>  /etc/apt/apt.conf
  echo "Acquire::https::Proxy \"${_original_proxy}\";" >>  /etc/apt/apt.conf
  _proxy="http_proxy=$_original_proxy https_proxy=$_original_proxy"
fi

# Install software pre-requisites
eval $_proxy apt-get update
#   Install git
eval $_proxy apt-get -y --force-yes install  git
#   Install pip
eval $_proxy apt-get -y --force-yes install  python-pip

#=================================================
# BASIC DEVSTACK
#=================================================
cd $_caller_home
# Clone devstack project with correct branch
sudo -u $_caller_user -H sh -c "eval $_proxy git clone https://git.openstack.org/openstack-dev/devstack -b $_branch devstack"
cd devstack

# Create local.conf file
sudo -u $_caller_user -H sh -c "cp ./samples/local.conf ./local.conf"

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

# Run install command
sudo -u $_caller_user -H sh -c "./stack.sh"

# Clean up _proxy from apt if added
if [[ ! -z "${_original_proxy}" ]]; then
  scaped_str=$(echo $_original_proxy | sed -s 's/[\/&]/\\&/g')
  sed -i "/$scaped_str/c\\" /etc/apt/apt.conf
fi


