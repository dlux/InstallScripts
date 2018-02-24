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

AddUser $_USER $_PASSWORD False
mkdir /home/$_USER/ftp
chown nobody:nogroup /home/$_USER/ftp
mod a-w /home/$_USER/ftp
mkdir /home/$_USER/ftp/files
chown $_USER:$_USER /home/$_USER/ftp/files
echo "vsftpd test file" | sudo tee /home/$_USER/ftp/files/test.txt

InstallFirewallUFW
SetFirewallUFW
[[ -n $(ufw status | grep -i status..active) ]] && OpenPorts

$_INSTALLER_CMD vsftpd

[[ -f /etc/vsftpd.conf ]] && fpath='/etc' || fpath='/etc/vsftpd'

file_name=$fpath/vsftpd.conf
fulist=$fpath/vsftpd.userlist

cp $file_name "${file_name}.orig"
sed -i "s/anonymous_enable/#anonymous_enable/g" $file_name
sed -i "/Allow anonymous FTP/a anonymous_enable=NO" $file_name
sed -i "s/local_enable/#local_enable/g" $file_name
sed -i "/allow local users/a local_enable=YES" $file_name
sed -i "s/#write_enable=YES/write_enable=YES/g" $file_name
sed -i "s/#chroot_local_user=YES/chroot_local_user=YES/g" $file_name

read -d '' extraConf <<- EOC
user_sub_token=\$USER
local_root=/home/\$USER/ftp
pasv_min_port=40000
pasv_max_port=50000
listen_port=45000
userlist_enable=YES
userlist_file=$fulist
userlist_deny=NO
EOC

echo $extraConf >> $file_name
echo $_USER | tee -a $fulist
systemctl restart vsftpd
echo "Testing access - List files"
file_list=$(curl -slu $_USER:$_PASSWORD ftp://localhost/files/)
[[ -z $(echo $file_list | grep test.txt) ]] && PrintError "Something went wrong"
echo "FTP server is setup properly"

# Cleanup _proxy from apt if added - first coincedence
[[ -n $_ORIGINAL_PROXY ]] && UnsetProxy $_ORIGINAL_PROXY

