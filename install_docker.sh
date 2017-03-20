#!/bin/bash
# ==========================================================
# This script installs docker via curl sh in a linux server
# Optionally send proxy server or file with full proxy info.
# =========================================================

# Uncomment the following line to debug
# set -o xtrace

# Ensure script is run as root
if [ "$EUID" -ne "0" ]; then
  echo "$(date +"%F %T.%N") ERROR : This script must be run as root." >&2
  exit 1
fi

# Set locale
locale-gen en_US
update-locale
export HOME=/root

#=================================================
# GLOBAL VARIABLES DEFINITION
#=================================================
_original_proxy=''
_proxy=''
_domain=',.intel.com'

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
    echo "Script installs docker server. Optionally uses given proxy"
    echo " "
    echo "Usage:"
    echo "./install_docker.sh [--proxy | -x <http://proxyserver:port>]"
    echo " "
    echo "     --proxy | -x     Uses the given proxy server to install the tools."
    echo "     --help           Prints current help text. "
    echo " "
    exit 1
}

# ============================= Processes docker installation options ============================
while [[ ${1} ]]; do
  case "${1}" in
    --proxy|-x)
      if [[ -z "${2}" || "${2}" == -* ]]; then
          PrintError "Missing proxy data."
      else
          _original_proxy="${2}"
          if [ -f /etc/apt/apt.conf ]; then
              echo "Acquire::http::Proxy \"${2}\";" >>  /etc/apt/apt.conf
              echo "Acquire::https::Proxy \"${2}\";" >>  /etc/apt/apt.conf
          elif [ -d /etc/apt/apt.conf.d ]; then
              echo "Acquire::http::Proxy \"${2}\";" >>  /etc/apt/apt.conf.d/70proxy.conf
              echo "Acquire::https::Proxy \"${2}\";" >>  /etc/apt/apt.conf.d/70proxy.conf
          fi
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

# ============================= Docker instalation ============================
# Update/Re-sync packages index
echo "Docker installation begins"

eval $_proxy apt-get -y -qq update
eval $_proxy apt-get -y -qq install wget

# Set gpg if server is behind a proxy
if [ -n "$_proxy" ]; then
     echo "Setting gpg since server is behind a proxy"
     eval $_proxy wget -qO- https://get.docker.com/gpg | apt-key add -
fi

# Install Docker
eval $_proxy wget -qO- https://get.docker.com/ | eval $_proxy sh

# Set docker proxy if server is behind a proxy
if [ -n "$_proxy" ]; then
	if [ -f /etc/default/docker ]; then
		stop docker
		# httpproxy=`expr "$proxy" : '\(.*\) https'`
		echo "export $_original_proxy" >> /etc/default/docker
		start docker
    fi
   # http_proxy_host=`expr "$http_proxy" : '\(.*\):'`
   # http_proxy_port=`expr "$http_proxy" : '.*\:\(.*\)'`
fi

# Verify Installation
echo "Verifying Docker installation."
eval $_proxy docker run hello-world
eval $_proxy docker run docker/whalesay cowsay Dlux test container running

echo "Adding caller user to docker group"
callerUser=$(who -m | awk '{print $1;}')
usermod -aG docker $callerUser
echo "Docker installation finished."
echo "Re-login with current user credentials."

# Cleanup proxy from apt if added - first coincedence
if [[ ! -z "${_original_proxy}" ]]; then
  scaped_str=$(echo $_original_proxy | sed -s 's/[\/&]/\\&/g')
  if [ -f /etc/apt/apt.conf ]; then
      sed -i "0,/$scaped_str/{/$scaped_str/d;}" /etc/apt/apt.conf
  elif [ -d /etc/apt/apt.conf.d ]; then
      sed -i "0,/$scaped_str/{/$scaped_str/d;}" /etc/apt/apt.conf.d/70proxy.conf
  fi
fi

