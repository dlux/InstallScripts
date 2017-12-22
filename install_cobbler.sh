#!/bin/bash
# ==========================================================
# This script install and setup cobbler and TFTP server
# to serve as the PXE server of a given network
# Optionally send proxy server to install packages 
# =========================================================

# Uncomment the following line to debug
 set -o xtrace

#=================================================
# GLOBAL FUNCTIONS
#=================================================
#echo '<UNDER DEVELOPMENT>' && exit 0

source common_packages

EnsureRoot
SetLocale /root
_PASSWORD='secure123'
# ========================= Processes installation options ===================
while [[ ${1} ]]; do
  case "${1}" in
    --help|-h)
      read -d '' opts <<- EOF
\      --password | -p  Cobbler password.
EOF
      PrintHelp "Install cobbler" $(basename "$0") \
      ""
      ;;
    --password|-p)
      [[ -z "${2}" ]] && PrintError "Must provide a password."
      _PASSWORD="${2}"
      shift
      ;;
    *)
      HandleOptions "$@"
      shift
  esac
  shift
done

# ============================= Cobbler instalation ==========================
[[ -n $http_proxy ]] && SetProxy $http_proxy

echo '-->  Install prereqs'
apt-get -y -qq update
InstallDhcp

echo '-->  Ensure SELinux is disabled or in permissive mode'
sudo apt-get install -y policycoreutils
[[ -n $(sestatus | grep enabled) ]] && setenforce 0

echo '-->  Installing cobbler and dependencies'.
apt-get install -y cobbler cobbler-web
# Fix issue with apache2 mod_python by dissabling it
a2dismod python
systemctl restart apache2
chown www-data /var/lib/cobbler/webui_sessions

echo 'CONFIGURE COBBLER:'
echo '-->  Changing cobbler encrypted password'
echo "$_PASSWORD" > ~/.cryptedPassword
crypt_pass=$(openssl passwd -1 -in ~/.cryptedPassword)
echo "$crypt_pass" > ~/.cryptedPassword
sed -i "s/^default_password_crypted.*$/default_password_crypted: \"$crypt_pass\"/g" /etc/cobbler/settings

echo '-->  Setting Server IPs'
HOST_IP=$(ip route get 8.8.8.8 | awk '{ print $NF; exit }')
if [[ -z $(cat /etc/cobbler/settings | grep -e "^server:.*$HOST_IP") ]]; then
    sed -i "s/^server:.*/server: $HOST_IP/g" /etc/cobbler/settings
    sed -i "s/^next_server:.*/next_server: $HOST_IP/g" /etc/cobbler/settings
fi

echo '-->  Configuring DHCP Management'
sed -i "s/^manage_dhcp.*/manage_dhcp: 1/g" /etc/cobbler/settings
# Modify DHCP net/ ip range
# Use default 192.168.1.0/24 (max 254 hosts)
ConfigDhcpapt

# Change data dir from /var/www to /opt/cobbler
# See http://cobbler.github.io/manuals/2.6.0/2/5_-_Relocating_Your_Installation.html
exit 0
cobbler sync
cobbler get-loaders
echo '-->  Starting cobbler.'
systemctl enable cobblerd.service
systemctl start cobblerd.service

# Cleanup _proxy from apt if added - first coincedence
UnsetProxy $_ORIGINAL_PROXY
