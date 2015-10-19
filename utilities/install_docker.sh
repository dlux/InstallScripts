#!/bin/bash
# ==========================================================
# This script installs docker via wget on a linux server
# Optionally send proxy file as parameter - Depends on get_proxy script
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

proxy=""

# ============================= Get Proxy information if passed as parameter ============================
while [[ ${1} ]]; do
  case "${1}" in
    --proxy|-x)
      if [ -f "${2}" ]; then
            echo "   Getting proxy information - Executing get proxy script"
            proxy=$(./get_proxy.sh -f ${2})
            echo "    Proxy set to: $proxy"
      else
           echo "Missing proxy file"
           exit 1
      fi
      shift
      ;;
    --help|-h)
      echo " "
      echo "Script installs docker."
      echo "Optionally use --proxy to pass proxy details to the installation"
      echo " "
      echo "Usage:"
      echo "     ./install_docker [--proxy | -x] <filePath>"
      echo " "
      echo "     --proxy <filePath>     Pass the full file name where proxy information lives"
      echo "     -x      <filePath>     Pass the full file name where proxy information lives."
      echo "     --help                 Prints current help text. "
      echo "Find Proxy File Sintaxis at https://github.com/dlux/InstallScripts/blob/master/shared/proxyrc.sample"
      echo " "
      exit 1
      ;;
    *)
      echo "***************************" >&2
      echo "* Error: Invalid argument. $1" >&2
      echo "  See ./install_docker --help" >&2
      echo "***************************" >&2
      exit 1
  esac
  shift
done

# ============================= Docker instalation ============================
# Update/Re-sync packages index
echo "Docker installation begins"

eval $proxy apt-get -y -qq update
eval $proxy apt-get -y -qq install wget

# Set gpg if server is behind a proxy
if [ ! -z "$proxy" ]; then
     echo "Setting gpg"
     eval $proxy wget -qO- https://get.docker.com/gpg | apt-key add -
fi

# Install Docker
eval $proxy wget -qO- https://get.docker.com/ | eval $proxy sh

# Set docker proxy if server is behind a proxy
if [ ! -z "$proxy" ]; then
	if [ -f /etc/default/docker ]; then
		stop docker
		httpproxy=`expr "$proxy" : '\(.*\) https'`
		echo "export $httpproxy" >> /etc/default/docker
		start docker
    fi
   # http_proxy_host=`expr "$http_proxy" : '\(.*\):'`
   # http_proxy_port=`expr "$http_proxy" : '.*\:\(.*\)'`
fi

# Verify Installation
echo "Verifying Docker installation."
eval $proxy docker run hello-world
eval $proxy docker run docker/whalesay cowsay Dlux test container running

echo "Adding caller user to docker group"
callerUser=$(who -m | awk '{print $1;}')
usermod -aG docker $callerUser
echo "Docker installation finished."
echo "Re-login with current user credentials."