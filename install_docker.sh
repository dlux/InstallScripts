#!/bin/bash
# ==========================================================
# This script installs docker via curl sh in a linux server
# Optionally send proxy server or file with full proxy info.
# =========================================================

# Comment the following line to be less verbosy
set -o xtrace

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
_domain=''

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
    echo "     --proxy  | -x     Uses the given proxy server to install the tools."
    echo "     --domain | -m     Use the given domain as server domain(non-proxy)."
    echo "     --help            Prints current help text. "
    echo " "
    exit 1
}

# ============================= Processes docker installation options ============================
while [[ ${1} ]]; do
  case "${1}" in
    --proxy|-x)
      if [[ -z "${2}" || "${2}" == -* ]]; then
          PrintError "Missing proxy server."
      else
          _original_proxy="${2}"
          if [ -f /etc/apt/apt.conf ]; then
              echo "Acquire::http::Proxy \"${2}\";" >>  /etc/apt/apt.conf
              echo "Acquire::https::Proxy \"${2}\";" >>  /etc/apt/apt.conf
          elif [ -d /etc/apt/apt.conf.d ]; then
              echo "Acquire::http::Proxy \"${2}\";" >>  /etc/apt/apt.conf.d/70proxy.conf
              echo "Acquire::https::Proxy \"${2}\";" >>  /etc/apt/apt.conf.d/70proxy.conf
          fi
          npx="127.0.0.0/8,localhost,10.0.0.0/8,192.168.0.0/16"
	  if [ ! -z "$_domain" ]; then
	      npx="$npx,${_domain}"
	  fi
          _proxy="http_proxy=${2} https_proxy=${2} no_proxy=${npx}"
          _proxy="$_proxy HTTP_PROXY=${2} HTTPS_PROXY=${2} NO_PROXY=${npx}"
      fi
      shift
      ;;
    --domain|-m)
      if [[ -z "${2}" || "${2}" == -* ]]; then
          PrintError "Missing domain information."
      else
          _domain="${2}"
	  if [ -z "$_proxy" ];then
  	      npx="127.0.0.0/8,localhost,10.0.0.0/8,192.168.0.0/16,${_domain}"
	      _proxy="no_proxy=${npx} NO_PROXY=${npx}"
	  else
	      _proxy=$(sed "s/no_proxy=/no_proxy=${_domain},/g" <<< "${_proxy}")
	      _proxy=$(sed "s/NO_PROXY=/NO_PROXY=${_domain},/g" <<< "${_proxy}")
	  fi
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
if [[ ! -z "$_proxy" ]]; then
     echo "Setting gpg since server is behind a proxy"
     eval $_proxy wget -qO- https://get.docker.com/gpg | apt-key add -
fi

# Install Docker
eval $_proxy wget -qO- https://get.docker.com/ | eval $_proxy sh

# Set docker proxy if server is behind a proxy
if [[ ! -z "$_proxy" ]]; then
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

echo "Adding caller user to docker group, so docker commands can run from non-root user."
caller_user=$(who -m | awk '{print $1;}')

if [[ -z "${caller_user}" ]]; then
    # If empty user then assume Vagrant script
    # Verify vagrant user exists then add it to docker user group
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
else
    echo "Adding $caller_user user to docker userGroup."
    usermod -aG docker $caller_user
fi

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

