#!/bin/bash

# ============================================================================
# Script upgrades Ubuntu 14.04 to Ubuntu 16.04
# ============================================================================

# Uncomment the following line to debug this script
# set -o xtrace

#=============================================================================
# GLOBAL FUNCTIONS
#=============================================================================
source common_functions

_LOCAL_USER='dlux'
_LOCAL_PASSWORD='secure123'

# ======================= Processes options =====================
while [[ ${1} ]]; do
  case "${1}" in
    --help|-h)
      PrintHelp "Upgrade Ubuntu Trusty to Xenial - From 14.04 to 16.04" $(basename "$0") \
                "     --user     | -u   User to be created locally. Defaults to dlux.
     --password | -p   The password for the user."
      ;;
    --password|-p)
      if [[ -z "${2}" || "${2}" == -* ]]; then
          PrintError "Missing user password."
      else
          _LOCAL_PASSWORD="${2}"
      fi
      shift
      ;;
    --user|-u)
      if [[ -z "${2}" || "${2}" == -* ]]; then
          PrintError "Missing user name."
      else
          _LOCAL_USER="${2}"
      fi
      shift
      ;;
    *)
      HandleOptions "$@"
      shift
  esac
  shift
done

# Ensure sudo is running script
EnsureRoot
SetLocale /root


# ============================================================================
# BEGIN UPGRADE
# Create Local User (in case VAS is on -- it will be broken at some point )
AddUser $_LOCAL_USER $_LOCAL_PASSWORD

# Reset apt repos to upstream Ubuntu
cat <<EOF > /etc/apt/sources.list
#------------------------------------------------------------------------------#
#                            OFFICIAL UBUNTU REPOS                         #
#------------------------------------------------------------------------------#
 
###### Ubuntu Main Repos
deb http://us.archive.ubuntu.com/ubuntu/ trusty main restricted universe multiverse
deb-src http://us.archive.ubuntu.com/ubuntu/ trusty main restricted universe multiverse
 
###### Ubuntu Update Repos
deb http://us.archive.ubuntu.com/ubuntu/ trusty-security main restricted universe multiverse
deb http://us.archive.ubuntu.com/ubuntu/ trusty-updates main restricted universe multiverse
deb-src http://us.archive.ubuntu.com/ubuntu/ trusty-security main restricted universe multiverse
deb-src http://us.archive.ubuntu.com/ubuntu/ trusty-updates main restricted universe multiverse

EOF

apt-get -y update
apt-get install -y update-manager
apt-get -y update
apt-get -y upgrade
apt-get -y dist-upgrade
apt-get install -y update-manager-core

# Make sure umask is 022
sed -i "s/^UMASK/#UMASK/g" /etc/login.defs
sed -i "/^#UMASK/a UMASK        022" /etc/login.defs

# Run Package Updates
# Unmanaged -- Might keeps old configuration (default options)
# Add default to apt installation
#echo 'DPkg::options { "--force-confdef"; "--force-confnew"; }' > /etc/apt/apt.conf.d/local
# Run upgrade script
#do-release-upgrade  -f DistUpgradeViewNonInteractive
mount -o remount,exec /tmp
apt-get dist-upgrade -y
do-release-upgrade
echo "PROCESS COMPLETED. REBOOT SYSTEM."

