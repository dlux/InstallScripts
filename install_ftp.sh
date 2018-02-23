#!/bin/bash
# ============================================================================
# This script installs and configure an ftp server via vsftpd
# ============================================================================

# Uncomment the following line to debug
# set -o xtrace

#=================================================
# GLOBAL FUNCTIONS
#=================================================

[[ ! -f common_packages ]] && curl -O https://raw.githubusercontent.com/dlux/InstallScripts/master/common_packages https://raw.githubusercontent.com/dlux/InstallScripts/master/common_functions

[[ ! -f common_packages ]] && echo 'Error. Unable to download common_packages.'

source common_packages

EnsureRoot

_APACHE=False
_HTTP_PORT=8080
_NGINX=False
_PASSWORD='secure123'
_USER='dlux4ftp'

# ======================= Processes installation options =====================
while [[ $1 ]]; do
  case "$1" in
    --help|-h)
      read -d '' extraOptsH <<- EOM
\      --password | -pw  Password for ftp user.
     --user     | -u   User for ftp servr. Default to dlux4ftp.
EOM
      PrintHelp "Install & configure FTP server" $(basename "$0") "$extraOptsH"
      ;;
    --password|-pw)
      [[ -z $2 ]] && PrintError "Password must be provided"
      _PASSWORD=$2
      shift
      ;;
    --user|-u)
      [[ -z $2 ]] && PrintError "User must be provided"
      _USER=$2
      shift
      ;;
    *)
      HandleOptions "$@"
      shift
  esac
  shift
done

# ========================= Configuration Section ============================
SetLocale /root
[[ -n $http_proxy ]] && SetProxy $http_proxy
[[ ! -z "$_PROXY" ]] && source .PROXY
UpdatePackageManager

function OpenPorts {
  ufw allow 20/tcp
  ufw allow 21/tcp
  ufw allow 990/tcp
  ufw allow 40000:50000/tcp
}

# ========================= Instalation ======================================
echo "FTP server installation begins"

AddUser $_USER $_PASSWORD
mkdir /home/$_USER/ftp
chown nobody:nogroup /home/$_USER/ftp
mod a-w /home/$_USER/ftp
mkdir /home/$_USER/ftp/files
chown $_USER:$_USER /home/$_USER/ftp/files
echo "vsftpd test file" | sudo tee /home/$_USER/ftp/files/test.txt

SetFirewallUFW
[[ -n ufw status |grep -i status..active ]] && OpenPorts

$_INSTALLER_CMD vsftpd
cp /etc/vsftpd.conf /etc/vsftpd.conf.orig
sed -i "s/anonymous_enable/#anonymous_enable/g" /etc/vsftpd.conf
sed -i "/Allow anonymous FTP/a anonymous_enable=NO" /etc/vsftpd.conf
sed -i "s/local_enable/#local_enable/g" /etc/vsftpd.conf
sed -i "/allow local users/a local_enable=YES" /etc/vsftpd.conf
sed -i "s/#write_enable=YES/write_enable=YES/g" /etc/vsftpd.conf
sed -i "s/#chroot_local_user=YES/chroot_local_user=YES/g" /etc/vsftpd.conf

read -d '' extraConf <<- EOC
user_sub_token=\$USER
local_root=/home/\$USER/ftp
pasv_min_port=40000
pasv_max_port=50000
listen_port=45000
userlist_enable=YES
userlist_file=/etc/vsftpd.userlist
userlist_deny=NO
EOC

echo $extraConf >> /etc/vsftpd.conf
echo $_USER | tee -a /etc/vsftpd.userlist
systemctl restart vsftpd
echo "Testing access - List files"
file_list=$(curl -slu $_USER:$_PASSWORD ftp://@localhost/files/ 2&1)
[[ -z $(echo $file_list | grep test.txt) ]] && PrintError "Something went wrong"
echo "FTP server is setup properly"

# Cleanup _proxy from apt if added - first coincedence
UnsetProxy $_ORIGINAL_PROXY

