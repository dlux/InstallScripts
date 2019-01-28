#!/bin/bash

# ============================================================================
# Script installs and configure booked - SW to Book anything you defined
# Assume: Ubuntu or CentOS distro. Mysql DB. PHP 5.5
# ============================================================================


# Uncomment the following line to debug this script
# set -o xtrace

# ================== Processes Functions =====================================

INSTALL_DIR=$(cd $(dirname "$0") && pwd)
_password="secrete9"

source $INSTALL_DIR/common_packages

function _PrintHelp {
    installTxt="Install and configure booked"
    scriptName=$(basename "$0")
    opts="     --password | -p     Use given password when needed.\n"
    PrintHelp "${installTxt}" "${scriptName}" "${opts}"
}

# ================== Processes script options ================================

EnsureRoot

while [[ ${1} ]]; do
  case "${1}" in
    --password|-p)
      msg="Missing password."
      if [[ -z $2 ]]; then PrintError "${msg}"; else _password="${2}"; fi
      shift
      ;;
    --help|-h)
      _PrintHelp
      ;;
    *)
      HandleOptions "$@"
      shift
  esac
  shift
done

# ================== Prerequisites ===========================================

# Install development tools
eval $_PROXY UpdatePackageManager
if [ $_PACKAGE_MANAGER == 'apt' ]; then
  eval $_PROXY $_INSTALLER_CMD unzip build-essential libapache2-mod-proxy-html libxml2-dev
else
  eval $_PROXY yum groupinstall 'Developmet Tools'
  eval $_PROXY $_INSTALLER_CMD unzip
fi

# Apache, Mysql, Php
eval $_PROXY InstallApache
eval $_PROXY InstallMysql "${_password}"
eval $_PROXY InstallPhp

# ================== Installation & Configuration ============================

# Customize Apache Error pages
CustomizeApache

# Create booked mysql configuration
mysql -uroot -p"${_password}" <<MYSQL_SCRIPT
DROP DATABASE IF EXISTS booked;
CREATE DATABASE booked;
CREATE USER 'booked_user'@'localhost' IDENTIFIED BY '${_password}123';
GRANT ALL PRIVILEGES ON booked . * TO 'booked_user'@'localhost';
FLUSH PRIVILEGES;
MYSQL_SCRIPT

# Get booked zip file
pushd /var/www/html
eval $_PROXY curl -O -J -L "https://sourceforge.net/projects/phpscheduleit/files/latest/download"

# Install booked
zip_file=$(find . -type f -name "booked-*")
unzip $zip_file
chmod -R 755 booked

[[ $_PACKAGE_MANAGER == 'apt' ]] && wuser='www-data' || wuser='apache'
chown -R $wuser:$wuser "booked/tpl"
chown -R $wuser:$wuser "booked/tpl_c"
rm $zip_file

# Configure booked - users, mysql, dbinfo
pushd "booked"

# Create php configuration
pushd config
cp config.dist.php config.php
sed -i "s#'http://localhost/Web'#'http://localhost/booked/Web'#g" config.php
sed -i "s#database....password.*#database']['password'] = '${_password}123';#g" config.php
sed -i "s#database....name.*#database']['name'] = 'booked';#g" config.php
sed -i "s/127.0.0.1/localhost/g" config.php
sed -i "s#install.password......#install.password'] = '8efcd42a8855a#g" config.php
popd #config

# Modify booked script
pushd database_schema
sed -i '/DROP DATABASE/d' full-install.sql
sed -i '/CREATE DATABASE/d' full-install.sql
sed -i '/GRANT ALL/d' full-install.sql
sed -i '1s/^/SET foreign_key_checks = 0;/'  full-install.sql
echo "SET foreign_key_checks = 1;" >>  full-install.sql

# Initialize DB by importing booked MySql schema
mysql -uroot -p"${_password}" booked < full-install.sql

# Add sample booking data
mysql -uroot -p"${_password}" booked < sample-data-utf8.sql

popd # database_schema
popd #booked

# Cleanup proxy 
UnsetProxy $_ORIGINAL_PROXY

echo "Installation Completed Successfully"
echo "Goto http://localhost/booked/. U/P: admin/password or user/password"

