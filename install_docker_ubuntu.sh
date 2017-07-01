#!/bin/bash
# ==========================================================
# This script installs docker on an Ubuntu system via apt system
# Optionally send proxy file as parameter - Runs get_proxy script
# =========================================================

# Uncomment the following line to debug
# set -o xtrace

#=================================================
# GLOBAL FUNCTIONS
#=================================================

source common_functions

EnsureRoot
SetLocale /root

# ================== Processes docker installation options ===================
while [[ ${1} ]]; do
  case "${1}" in
    --help|-h)
      PrintHelp "Install docker via apt" $(basename "$0")
      ;;
    *)
      HandleOptions "$@"
      shift
  esac
  shift
done

# ============================= Docker instalation ===========================
# Update/Re-sync packages index
echo "Docker installation begins"

# Get server OS release version
release=$(lsb_release -cs)


# Update apt sources
eval $_PROXY apt-get -y -qq update
eval $_PROXY apt-get install -y ubuntu-cloud-keyring
eval $_PROXY apt-get -y -qq update

# Add gpg key
eval $_PROXY apt-key adv --keyserver hkp://pgp.mit.edu:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D

# docker source list
rm /etc/apt/sources.list.d/docker.list
echo "deb https://apt.dockerproject.org/repo ubuntu-$release main" > /etc/apt/sources.list.d/docker.list
eval $_PROXY apt-get -y -qq update

# Install Docker
eval $_PROXY apt-get install docker-engine

# Set docker proxy if server is behind a proxy
if [ ! -z "$_PROXY" ]; then
	if [ -f /etc/default/docker ]; then
		stop docker
		echo "export $http_proxy_" >> /etc/default/docker
		start docker
    fi
fi

# Verify Installation
echo "Verifying Docker installation."
eval $_PROXY docker run hello-world
eval $_PROXY docker run docker/whalesay cowsay Dlux test container running

echo "Adding caller user to docker group"
callerUser=$(who -m | awk '{print $1;}')
caller_user=${caller_user:-'ubuntu'}
usermod -aG docker $callerUser
echo "Docker installation finished."
echo "Re-login with current user credentials."

# Cleanup _proxy from apt if added - first coincedence
UnsetProxy
