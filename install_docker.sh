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

[[ ! -z "$_PROXY" ]] && source .PROXY

echo "Update Repos"
apt-get -y -qq update
apt-get -y -qq install wget

# Set gpg if server is behind a proxy
#if [[ ! -z "$_PROXY" ]]; then
#     echo "Setting gpg since server is behind a proxy"
#     wget -qO- https://get.docker.com/gpg | apt-key add -
#fi

# Install Docker
echo "Install Docker"
wget -qO- https://get.docker.com/ | sh

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
        line="Environment=\"HTTP_PROXY=$_ORIGINAL_PROXY/\" \"NO_PROXY=$npx\"  \"HTTP_PROXY=$_ORIGINAL_PROXY/\""
        p_path='/etc/systemd/system/docker.service.d'

        mkdir -p $p_path

        if [ -f ${p_path}/http-proxy.conf ]; then
            sed -i "/\[Service\]/ a $line" ${p_path}/http-proxy.conf
        else
            echo '[Service]' > ${p_path}/http-proxy.conf
            echo "$line" >> ${p_path}/http-proxy.conf
        fi

	if [ -f /lib/systemd/system/docker.service ]; then
	  sed -i "/\[Service\]/ a $line" /lib/systemd/system/docker.service
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
docker run hello-world
docker run docker/whalesay cowsay Dlux test container running

echo "Adding caller user to docker group, so docker commands can run from non-root user."
caller_user=$(who -m | awk '{print $1;}')
if [[ -z "${caller_user}" ]]; then
    # If empty caller user then assume Vagrant script
    getent passwd vagrant  > /dev/null
    [[ $? -eq 0 ]] && caller_user=vagrant || caller_user=ubuntu
fi
echo "Adding $caller_user user to docker userGroup."
usermod -aG docker $caller_user

echo "Docker installation finished."
echo "Re-login with current user credentials."

# Cleanup _proxy from apt if added - first coincedence
UnsetProxy $_ORIGINAL_PROXY
