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
      PrintHelp "Install cobbler" $(basename "$0")
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

apt-get -y -qq update
apt-get -y install python
./install_devtools.sh

InstallApache
CustomizeApache
InstallApacheMod wsgi
InstallApacheMod ssl
InstallApacheMod fqdn
apt-get -y install createrepo mkisofs python-cheetah python-netaddr \
    python-simplejson python-urlgrabber python-yaml rsync syslinux \
    python-django python-setuptools openssl

# TFTP
InstallTftp
apt-get -y install atftpd
ln -s /srv/tftp /var/lib/tftpboot

# Cobbler
apt-get -y install cobbler cobbler-web
chown www-data /var/lib/cobbler/webui_sessions
# Fix issue with apache2 mod_python by dissabling it
a2dismod python
systemctl restart apache2
systemctl status apache2

echo "Changing cobbler encrypted password"
echo "$_PASSWORD" > ~/.cryptedPassword
crypt_pass=$(openssl passwd -1 -in ~/.cryptedPassword)
echo "$crypt_pass" > ~/.cryptedPassword
sed -i "s/^default_password_crypted.*$/default_password_crypted: \"$crypt_pass\"/g"/etc/cobbler/settings
# sed -i "s/^server:.*/server: $IP/g" /etc/cobbler/settings

echo "Configuring DHCP Management"
sed -i "s/^manage_dhcp.*/manage_dhcp: 1/g" /etc/cobbler/settings

# Cleanup _proxy from apt if added - first coincedence
UnsetProxy $_ORIGINAL_PROXY
