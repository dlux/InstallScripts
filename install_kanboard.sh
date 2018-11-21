#!/bin/bash

# ============================================================================
# Script installs and configure kanboard - SW to manage kanban projects
# Assume: Ubuntu distro. Mysql DB.
# ============================================================================


# Uncomment the following line to debug this script
# set -o xtrace

# ================== Processes Functions =====================================

INSTALL_DIR=$(cd $(dirname "$0") && pwd)
_password="secrete9"
_release="1.2.6"

source $INSTALL_DIR/common_packages

function _PrintHelp {
    installTxt="Install and configure kanboard"
    scriptName=$(basename "$0")
    opts="     --password | -p     Use given password when needed.\n"
    opts="$opts     --release  | -r     Install given kanboard release. Default to 1.2.3"
    PrintHelp "${installTxt}" "${scriptName}" "${opts}"
}

# ================== Processes script options ================================

EnsureRoot
SetLocale /root

while [[ ${1} ]]; do
  case "${1}" in
    --password|-p)
      msg="Missing password."
      if [[ -z $2 ]]; then PrintError "${msg}"; else _password="${2}"; fi
      shift
      ;;
    --release|-r)
      msg="Missing release."
      if [[ -z $2 ]]; then PrintError "${msg}"; else _release="${2}"; fi
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
eval $_PROXY apt-get update
eval $_PROXY apt-get install -y wget curl unzip
eval $_PROXY apt-get install -y build-essential libapache2-mod-proxy-html libxml2-dev


# Apache, Mysql, Php
eval $_PROXY InstallApache
eval $_PROXY InstallMysql "${_password}"
eval $_PROXY InstallPhp

# ================== Installation & Configuration ============================

# Customize Apache Error pages
CustomizeApache

# Create kanboard mysql configuration
mysql -uroot -p"${_password}" <<MYSQL_SCRIPT
CREATE DATABASE kanboard;
CREATE USER 'kanboard'@'localhost' IDENTIFIED BY '$_password';
GRANT ALL PRIVILEGES ON kanboard . * TO 'kanboard'@'localhost';
FLUSH PRIVILEGES;
MYSQL_SCRIPT

# Get kanboard zip file
pushd /var/www/html
release_file="v${_release}.zip"
eval $_PROXY wget "https://github.com/kanboard/kanboard/archive/$release_file"

# Install kanboard
unzip $release_file
chown -R www-data:www-data "kanboard-${_release}"/data
rm $release_file

# Install Auth Github plugin
#pushd kanboard/plugins
#eval $_PROXY wget https://github.com/kanboard/plugin-github-auth/archive/v1.0.3.zip
#unzip v1.0.3.zip
#rm v1.0.3.zip
#popd

# Configure kanboard - users, mysql, dbinfo
pushd "kanboard-${_release}"

# Create php configuration
cp config.default.php config.php
sed -i "s/DEBUG', false/DEBUG', true/g" config.php
sed -i "s/LOG_DRIVER', ''/LOG_DRIVER', 'file'/g" config.php
sed -i "s/MAIL_CONFIGURATION', true/MAIL_CONFIGURATION', false/g" config.php
sed -i "s/sqlite'/mysql'/g" config.php
sed -i "s/DB_USERNAME', 'root/DB_USERNAME', 'kanboard/g" config.php
sed -i "s/DB_PASSWORD.*.'/DB_PASSWORD', '${_password}'/g" config.php
# These must be set once app is registered on git
# Further info https://developer.github.com/v3/guides/basics-of-authentication/
#echo "// Github client id (Copy it from your settings -> Applications -> Developer applications)" >> config.php
#echo "define('GITHUB_CLIENT_ID', 'YOUR_GITHUB_CLIENT_ID');" >> config.php
#echo "// Github client secret key (Copy it from your settings -> Applications -> Developer applications)" >> config.php
#echo "define('GITHUB_CLIENT_SECRET', 'YOUR_GITHUB_CLIENT_SECRET');" >> config.php

# Initialize DB by importing Kanboard MySql schema
mysql -uroot -p"${_password}" kanboard < app/Schema/Sql/mysql.sql

popd
popd

# Cleanup proxy 
UnsetProxy $_ORIGINAL_PROXY

echo "Installation Completed Successfully"
echo "Goto http://localhost/kanboard-${_release}. U/P: admin/admin"

