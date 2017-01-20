#!/bin/bash

# ==============================================================================
# Script installs and configure a refstack server (UI and API):
# See: https://github.com/openstack/refstack/blob/master/doc/source/refstack.rst
# ==============================================================================

# Comment the following line to stop debugging this script
 set -o xtrace
# Comment the following like to stop script on failure (Fail fast)
# set -e

#=================================================
# GLOBAL VARIABLES DEFINITION
#=================================================
_original_proxy=''
_proxy=''
_domain=',.intel.com'
_password='secure123'

#=================================================
# GLOBAL FUNCTIONS
#=================================================
function PrintError {
    echo "************************" >&2
    echo "* $(date +"%F %T.%N") ERROR: $1" >&2
    echo "************************" >&2
    exit 1
}

function PrintHelp {
    echo " "
    echo "Script installs RefStack Server."
    echo " "
    echo "Usage:"
    echo "./install_refstack.sh [--proxy | -x <http://proxyserver:port>] [--password|-p <pwd>]"
    echo " "
    echo "     --proxy | -x     Uses the given proxy server to install the tools."
    echo "     --password | -p  Uses the given password for refstack database."
    echo "     --help           Prints current help text. "
    echo " "
    exit 1
}

# Ensure script is run as root
if [ "$EUID" -ne "0" ]; then
  PrintError "This script must be run as root."
fi

# ============================= Process installation options ============================
while [[ ${1} ]]; do
  case "${1}" in
    --proxy|-x)
      if [[ -z "${2}" || "${2}" == -* ]]; then
          PrintError "Missing proxy data."
      else
          if [ -f /etc/apt/apt.conf ]; then
              echo "Acquire::http::Proxy \"${2}\";" >>  /etc/apt/apt.conf
              echo "Acquire::https::Proxy \"${2}\";" >>  /etc/apt/apt.conf
          elif [ -d /etc/apt/apt.conf.d ]; then
              echo "Acquire::http::Proxy \"${2}\";" >>  /etc/apt/apt.conf.d/70proxy.conf
              echo "Acquire::https::Proxy \"${2}\";" >>  /etc/apt/apt.conf.d/70proxy.conf
          fi
          _original_proxy="${2}"
          npx="127.0.0.0/8,localhost,10.0.0.0/8,192.168.0.0/16${_domain}"
          _proxy="http_proxy=${2} https_proxy=${2} no_proxy=${npx}"
          _proxy="$_proxy HTTP_PROXY=${2} HTTPS_PROXY=${2} NO_PROXY=${npx}"
      fi
      shift
      ;;
    --password|-p)
      if [[ -z "${2}" || "${2}" == -* ]]; then
          PrintError "Missing password."
      else
          _password="${2}"
      fi
      shift
      ;;
    --help|-h)
      PrintHelp
      ;;
    *)
      PrintError "Invalid Argument."
  esac
  shift
done

# ==================================== Install Dependencies ==========================================
eval $_proxy wget https://raw.githubusercontent.com/dlux/InstallScripts/master/install_devtools.sh
chmod +x install_devtools.sh
if [ -z "${_original_proxy}" ]; then
    ./install_devtools.sh
else
    ./install_devtools.sh -x $_original_proxy
fi
rm install_devtools.sh

eval $_proxy apt-get install -y python-setuptools python-mysqldb
debconf-set-selections <<< "mysql-server mysql-server/root_password password ${_password}"
debconf-set-selections <<< "mysql-server mysql-server/root_password_again password ${_password}"
eval $_proxy apt-get install -q -y mysql-server

eval $_proxy curl -sL https://deb.nodesource.com/setup_4.x | eval $_proxy bash -
eval $_proxy apt-get install -y nodejs
# ======================================= Setup Database ============================================
mysql -uroot -p"${_password}" <<MYSQL_SCRIPT
CREATE DATABASE refstack;
CREATE USER 'refstack'@'localhost' IDENTIFIED BY '$_password';
GRANT ALL PRIVILEGES ON refstack . * TO 'refstack'@'localhost';
FLUSH PRIVILEGES;

MYSQL_SCRIPT

# ======================================= Setup Refstack ============================================
caller_user=$(who -m | awk '{print $1;}')
caller_user=${caller_user:-'vagrant'}
host="$(hostname)"
domain="$(hostname -d)"
fqdn=$host
if [ -n "${domain}" ]; then
    fqdn="$host.$domain"
fi

export http_proxy="${_original_proxy}"
export https_proxy="${_original_proxy}"
sudo -HE -u $caller_user bash -c 'git clone http://github.com/openstack/refstack'
sudo -HE -u $caller_user bash -c 'git clone http://github.com/openstack/refstack-client'
cd refstack
sudo -HE -u $caller_user bash -c 'virtualenv .venv --system-site-package'
source .venv/bin/activate
eval $_proxy pip install .
sudo -HE -u $caller_user bash -c 'npm install'


sudo -HE -u $caller_user bash -c 'cp etc/refstack.conf.sample etc/refstack.conf'
sed -i "s/#connection = <None>/connection = mysql+pymysql\:\/\/refstack\:$_password\@localhost\/refstack/g" etc/refstack.conf
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

# Start refstack server daemon
# refstack-api --env REFSTACK_OSLO_CONFIG=etc/refstack.conf

if [[ ! -z "${_original_proxy}" ]]; then
  scaped_str=$(echo $_original_proxy | sed -s 's/[\/&]/\\&/g')
  if [ -f /etc/apt/apt.conf ]; then
      sed -i "0,/$scaped_str/{/$scaped_str/d;}" /etc/apt/apt.conf
  elif [ -d /etc/apt/apt.conf.d ]; then
      sed -i "0,/$scaped_str/{/$scaped_str/d;}" /etc/apt/apt.conf.d/70proxy.conf
  fi
fi

