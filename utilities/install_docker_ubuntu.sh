#!/bin/bash
# ==========================================================
# This script installs docker on an Ubuntu system via apt system
# Optionally send proxy file as parameter - Runs get_proxy script
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
            echo "   Getting proxy information."
            http_proxy_=$(awk -F "=" '/http_proxy/ {print $2}' ${2})
            https_proxy_=$(awk -F "=" '/https_proxy/ {print $2}' ${2})
            no_proxy_=$(awk -F "=" '/no_proxy/ {print $2}' ${2})
            proxy="http_proxy=${http_proxy_} https_proxy=${https_proxy_} no_proxy=${no_proxy_}"
            echo "    Proxy set to: $proxy"
      else
           echo "Missing proxy file. See file fintaxis at ~/InstallScripts/utilities/proxyrc.sample"
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
      echo "Find Proxy File Sintaxis at https://github.com/dlux/InstallScripts/blob/master/utilities/proxyrc.sample"
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

# Get server OS release version
release=$(lsb_release -cs)


# Update apt sources
eval $proxy apt-get -y -qq update
eval $proxy apt-get install -y ubuntu-cloud-keyring
eval $proxy apt-get -y -qq update

# Add gpg key
eval $proxy apt-key adv --keyserver hkp://pgp.mit.edu:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D

# docker source list
rm /etc/apt/sources.list.d/docker.list
echo "deb https://apt.dockerproject.org/repo ubuntu-$release main" > /etc/apt/sources.list.d/docker.list
eval $proxy apt-get -y -qq update

# Install Docker
eval $proxy apt-get install docker-engine

# Set docker proxy if server is behind a proxy
if [ ! -z "$proxy" ]; then
	if [ -f /etc/default/docker ]; then
		stop docker
		echo "export $http_proxy_" >> /etc/default/docker
		start docker
    fi
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

