#!/bin/bash

# ==============================================================================
# Script installs and configure znc - IRC bouncer server.
# Assume Ubuntu distribution.
# ==============================================================================


# Uncomment the following line to debug this script
# set -o xtrace

#=================================================
# GLOBAL VARIABLES DEFINITION
#=================================================
_original_proxy=''
_proxy=''
_domain=',.intel.com'
_ip_add=""

#=================================================
# GLOBAL FUNCTIONS
#=================================================
# Error Function
function PrintError {
    echo "************************" >&2
    echo "* $(date +"%F %T.%N") ERROR: $1" >&2
    echo "************************" >&2
    exit 1
}

function PrintHelp {
    echo " "
    echo "Script installs and configure znc IRC bouncer. Optionally accepts proxy server - to be handled by proxychains."
    echo " "
    echo "Usage:"
    echo "./install_znc.sh [--proxy | -x <http://127.0.0.1:port>]"
    echo " "
    echo "     --proxy | -x     Uses the given proxy for the configuration."
    echo "     --help           Prints current help text. "
    echo " "
    exit 1
}

function ValidIP {
    local  ip=$1
    local  stat=1

    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        OIFS=$IFS
        IFS='.'
        ip=($ip)
        IFS=$OIFS
        [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 \
            && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
        stat=$?
    fi

    echo $stat
}

# Ensure script is run as NO root
if [ "$EUID" -eq "0" ]; then
  PrintError "This script must NOT be run as root."
fi

# Set locale
locale-gen en_US
update-locale
export HOME=/root

# ============================= Processes installation options ============================
while [[ ${1} ]]; do
  case "${1}" in
    --proxy|-x)
      if [[ -z "${2}" || "${2}" == -* ]]; then
          PrintError "Missing proxy data."
      else
          _original_proxy="${2}"
          # Make sure proxy is given as an IP address
          _ip_add=$(echo ${2} | awk -F "//" '{print $2}' | awk -F ":" '{print $1}')

          if [[ $(ValidIP $_ip_add) -eq 1 ]]; then
            PrintError "Proxy server must be an IP addresss not host name."
          fi

          # Set proxy for apt repositories
          if [ -f /etc/apt/apt.conf ]; then
              echo "Acquire::http::Proxy \"${2}\";" | sudo tee -a /etc/apt/apt.conf
          elif [ -d /etc/apt/apt.conf.d ]; then
              echo "Acquire::http::Proxy \"${2}\";" | sudo tee -a /etc/apt/apt.conf.d/70proxy.conf
          fi

          # set env vars
          npx="127.0.0.0/8,localhost,10.0.0.0/8,192.168.0.0/16${_domain}"
          _proxy="http_proxy=${2} https_proxy=${2} no_proxy=${npx}"
          _proxy="$_proxy HTTP_PROXY=${2} HTTPS_PROXY=${2} NO_PROXY=${npx}"
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
# ============================================================================================
# BEGIN PACKAGE INSTALATION

# Install development tools
eval $_proxy sudo -E apt-get update
eval $_proxy sudo -E apt-get install -y --force-yes build-essential libssl-dev libffi-dev libpq-dev
eval $_proxy sudo -E apt-get install -y --force-yes build-dep libperl-dev pkg-config

# Get tarball
eval $_proxy wget http://znc.in/releases/znc-1.6.5.tar.gz -O znc.tar.gz

# Extract tarball
tar -xzvf znc.tar.gz
mv znc-1.6.5 znc
cd znc

# compile
./configure
make
make install

# Create config file
znc --makeconf

# If behind proxy, install, configure proxychains and re-run znc under it
if [[ ! -z "${_proxy}" ]]; then
    eval $_proxy sudo -E apt-get install proxychains

    # Modify default proxy settings
    sudo sed -i 's/socks4/\#socks4/g' /etc/proxychains.conf
    sudo sed -i "/socks4/ a socks5  ${_ip_add}  1080" /etc/proxychains.conf

    # Restart znc
    sudo pkill -SIGUSR1 znc
    sleep 1
    sudo pkill znc
    sleep 1
    proxychains znc
fi

# Cleanup _proxy from apt if added - first coincedence
if [[ ! -z "${_original_proxy}" ]]; then
  scaped_str=$(echo $_original_proxy | sed -s 's/[\/&]/\\&/g')
  if [ -f /etc/apt/apt.conf ]; then
      sudo sed -i "0,/$scaped_str/{/$scaped_str/d;}" /etc/apt/apt.conf
  elif [ -d /etc/apt/apt.conf.d ]; then
      sudo sed -i "0,/$scaped_str/{/$scaped_str/d;}" /etc/apt/apt.conf.d/70proxy.conf
  fi
fi
