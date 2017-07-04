#!/bin/bash
# ==========================================================
# This script install and setup cobbler and TFTP server
# to serve as the PXE server of a given network
# Optionally send proxy server to install packages 
# =========================================================

# Uncomment the following line to debug
# set -o xtrace

#=================================================
# GLOBAL FUNCTIONS
#=================================================
<UNDER DEVELOPMENT>
source common_packages

EnsureRoot
SetLocale /root

# ========================= Processes installation options ===================
while [[ ${1} ]]; do
  case "${1}" in
    --help|-h)
      PrintHelp "Install cobbler" $(basename "$0")
      ;;
    *)
      HandleOptions "$@"
      shift
  esac
  shift
done

# ============================= Cobbler instalation ===========================
# Update/Re-sync packages index
eval $_PROXY apt-get -y -qq update

InstallTftp

# Cobbler
eval $_PROXY apt-get -y -qq install cobbler

crypt_pass=$(openssl passwd -1)

echo "Encrypted password: " $crypt_pass >> ~/passwords
sed -i "s/default_password_crypted.*$/default_password_crypted:$crypt_pass/g"



# Cleanup _proxy from apt if added - first coincedence
UnsetProxy
