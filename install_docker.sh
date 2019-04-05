#!/bin/bash
# ===========================================================
# This script installs docker via wget script on linux server
# Optionally send proxy variable
# ===========================================================

# Uncomment the following line to debug
# set -o xtrace

#=================================================
# GLOBAL FUNCTIONS
#=================================================

source common_functions

EnsureRoot

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

UpdatePackageManager

# Install Docker
echo "Install Docker"
wget -qO- https://get.docker.com/ | sh

# Set docker proxy if server is behind a proxy
if [[ ! -z "$_PROXY" ]]; then
    echo "Set proxy on docker systemd service file."
    systemctl stop docker
    line="Environment=\"HTTP_PROXY=$_ORIGINAL_PROXY/\" \"NO_PROXY=$npx\""
    line="$line \"HTTP_PROXY=$_ORIGINAL_PROXY/\""
    _path='/etc/systemd/system/docker.service.d'

    mkdir -p $_path

    if [ -f $_path/http-proxy.conf ]; then
        sed -i "/\[Service\]/ a $line" $_path/http-proxy.conf
    else
        echo '[Service]' > $_path/http-proxy.conf
        echo "$line" >> $_path/http-proxy.conf
    fi
    if [ -f /lib/systemd/system/docker.service ]; then
        sed -i "/\[Service\]/ a $line" /lib/systemd/system/docker.service
    fi

    echo "Reloading Docker."
    systemctl daemon-reload

    echo "Restarting Docker."
    systemctl start docker
fi

# Verify Installation
echo "Verifying Docker installation."
docker run hello-world
docker run docker/whalesay cowsay Dlux test container running

echo "Adding caller user to docker group."
echo "This will allow docker commands run from non-root user."
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
