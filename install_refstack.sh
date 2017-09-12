#!/bin/bash

# ==============================================================================
# Script installs and configure a refstack server (UI and API):
# See: https://github.com/openstack/refstack/blob/master/doc/source/refstack.rst
# ==============================================================================

# Comment the following line to stop debugging this script
# set -o xtrace
# Comment the following like to stop script on failure (Fail fast)
 set -e

#=================================================
# GLOBAL DEFINITION
#=================================================
_PASSWORD='secure123'

source common_functions

EnsureRoot
SetLocale /root

# ======================= Processes installation options =====================
while [[ ${1} ]]; do
  case "${1}" in
    --password|-p)
      if [[ -z "${2}" || "${2}" == -* ]]; then
          PrintError "Missing password."
      else
          _PASSWORD="${2}"
      fi
      shift
      ;;
    --help|-h)
      PrintHelp "Install refstack server " $(basename "$0")
      ;;
    
    *)
      HandleOptions "$@"
      shift
  esac
  shift
done

# ==================================== Install Dependencies ==========================================

if [ -z "${_ORIGINAL_PROXY}" ]; then
    ./install_devtools.sh
else
    ./install_devtools.sh -x $_ORIGINAL_PROXY
fi
eval $_PROXY apt-get install -y python-setuptools python-mysqldb
debconf-set-selections <<< "mysql-server mysql-server/root_password password ${_PASSWORD}"
debconf-set-selections <<< "mysql-server mysql-server/root_password_again password ${_PASSWORD}"
eval $_PROXY apt-get install -q -y mysql-server

eval $_PROXY curl -sL https://deb.nodesource.com/setup_4.x | eval $_PROXY bash -
eval $_PROXY apt-get install -y nodejs
# ======================================= Setup Database ============================================
mysql -uroot -p"${_PASSWORD}" <<MYSQL_SCRIPT
CREATE DATABASE refstack;
CREATE USER 'refstack'@'localhost' IDENTIFIED BY '$_PASSWORD';
GRANT ALL PRIVILEGES ON refstack . * TO 'refstack'@'localhost';
FLUSH PRIVILEGES;

MYSQL_SCRIPT
# ======================================= Setup Refstack ============================================
caller_user=$(who -m | awk '{print $1;}')
caller_user=${caller_user:-'ubuntu'}
host="$(hostname)"
domain="$(hostname -d)"
fqdn=$host
if [ -n "${domain}" ]; then
    fqdn="$host.$domain"
fi

export http_proxy="${_ORIGINAL_PROXY}"
export https_proxy="${_ORIGINAL_PROXY}"
sudo -HE -u $caller_user bash -c 'git clone http://github.com/openstack/refstack'
sudo -HE -u $caller_user bash -c 'git clone http://github.com/openstack/refstack-client'
cd refstack
sudo -HE -u $caller_user bash -c 'virtualenv .venv --system-site-package'
source .venv/bin/activate
eval $_PROXY pip install .
sudo -HE -u $caller_user bash -c 'npm install'


sudo -HE -u $caller_user bash -c 'cp etc/refstack.conf.sample etc/refstack.conf'
sed -i "s/#connection = <None>/connection = mysql+pymysql\:\/\/refstack\:$_PASSWORD\@localhost\/refstack/g" etc/refstack.conf
sed -i "/ui_url/a ui_url = http://$fqdn:8000" etc/refstack.conf
sed -i "/api_url/a api_url = http://$fqdn:8000" etc/refstack.conf
sed -i "/app_dev_mode/a app_dev_mode = true" etc/refstack.conf
sed -i "/debug = false/a debug = true" etc/refstack.conf

sudo -HE -u $caller_user bash -c 'cp refstack-ui/app/config.json.sample refstack-ui/app/config.json'
sed -i "s/refstack.openstack.org\/api/$fqdn:8000/g" refstack-ui/app/config.json

# DB SYNC IF VERSION IS None
version="$(refstack-manage --config-file etc/refstack.conf version | grep -i none)"
if [ ! -z "${version}" ]; then
    refstack-manage --config-file etc/refstack.conf upgrade --revision head
    version="$(refstack-manage --config-file etc/refstack.conf version | grep -i none)"

    if [ ! -z "${version}" ]; then
         PrintError "After sync DB, version is still displayed as None. $version"
    fi
fi

# Install refstack client
echo "INSTALLING REFSTACK CLIENT"
cd ../refstack-client
./setup_env

echo "Finished successfully"
echo "Start refstack server daemon by running following command on a screen session:"
echo " refstack-api --env REFSTACK_OSLO_CONFIG=etc/refstack.conf"

# Cleanup _proxy from apt if added - first coincedence
UnsetProxy
