#!/bin/bash
# ==========================================================
# This script installs docker via wget script for a linux server
# Optionally send proxy server or file with full proxy info.
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
      PrintHelp "Install docker" $(basename "$0")
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

echo "Update Repos"
eval $_PROXY apt-get -y -qq update
eval $_PROXY apt-get -y -qq install wget

# Set gpg if server is behind a proxy
#if [[ ! -z "$_PROXY" ]]; then
#     echo "Setting gpg since server is behind a proxy"
#     eval $_PROXY wget -qO- https://get.docker.com/gpg | apt-key add -
#fi

# Install Docker
echo "Install Docker"
eval $_PROXY wget -qO- https://get.docker.com/ | eval $_PROXY sh

# Set docker proxy if server is behind a proxy
if [[ ! -z "$_PROXY" ]]; then

    echo "Setup proxy on docker."

    # Check if not systemd (ubuntu 14.04)
    stop docker  > /dev/null
    if [ $? -eq 0 ]; then
        echo "Set proxy on /etc/default/docker - NON SYSTEMD"
	httpproxy=`expr "$_PROXY" : '\(.*\) https'`
	echo "export $httpproxy" >> /etc/default/docker

	echo "Restarting Docker."
	start docker
    else
        echo "Set proxy on docker systemd service file."
	service docker stop
	if [ -f /etc/systemd/system/docker.service.d/http-proxy.conf ]; then
	  sed -i "/\[Service\]/ a Environment=\"HTTP_PROXY=${_ORIGINAL_PROXY}\"" /etc/systemd/system/docker.service.d/http-proxy.conf
	elif [ -f /lib/systemd/system/docker.service ]; then
	  sed -i "/\[Service\]/ a Environment=\"HTTP_PROXY=${_ORIGINAL_PROXY}\"" /lib/systemd/system/docker.service
	fi
	
	echo "Reloading Docker."
	systemctl daemon-reload
	
	echo "Restarting Docker."
	service docker start
    fi
   # proxy_host=`expr "$http_proxy" : '\(.*\):'`
   # proxy_port=`expr "$http_proxy" : '.*\:\(.*\)'`
fi

# Verify Installation
echo "Verifying Docker installation."
eval $_PROXY docker run hello-world
eval $_PROXY docker run docker/whalesay cowsay Dlux test container running

echo "Adding caller user to docker group, so docker commands can run from non-root user."
caller_user=$(who -m | awk '{print $1;}')

if [[ ! -z "${caller_user}" ]]; then
    echo "Adding $caller_user user to docker userGroup."
    usermod -aG docker $caller_user
else
    # Assume Vagrant script
    getent passwd vagrant  > /dev/null
    if [ $? -eq 0 ]; then
        echo "Adding vagrant user to docker userGroup."
        usermod -aG docker vagrant
    fi
    getent passwd ubuntu  > /dev/null
    if [ $? -eq 0 ]; then
        echo "Adding ubuntu user to docker userGroup."
        usermod -aG docker ubuntu
    fi
fi

echo "Docker installation finished."
echo "Re-login with current user credentials."

# Cleanup _proxy from apt if added - first coincedence
UnsetProxy
