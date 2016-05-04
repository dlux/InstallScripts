#!/bin/bash
# ==========================================================
# This script installs ruby 1.9, puppet, and puppet librarian
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
      echo "Script installs ruby 1.9, puppet, and puppet librarian."
      echo "Optionally use --proxy to pass proxy details to the installation"
      echo " "
      echo "Usage:"
      echo "     ./install_puppet [--proxy | -x] <filePath>"
      echo " "
      echo "     --proxy <filePath>     The full file name where proxy information lives"
      echo "     -x      <filePath>     The full file name where proxy information lives."
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

# Update/Re-sync packages index (to reflect new puppet enabled package)
eval $proxy apt-get -qq update

# ============================= RUBY INSTALLATION ============================
# Install ruby 9 - 1.9.3
eval $proxy apt-get -y --force-yes install ruby1.9.1
eval $proxy apt-get -y --force-yes install ruby1.9.1-dev
eval $proxy apt-get -y --force-yes install rubygems1.9.1
eval $proxy apt-get -y --force-yes install irb1.9.1
eval $proxy apt-get -y --force-yes install ri1.9.1
eval $proxy apt-get -y --force-yes install rdoc1.9.1
eval $proxy apt-get -y --force-yes install build-essential
eval $proxy apt-get -y --force-yes install libopenssl-ruby1.9.1
eval $proxy apt-get -y --force-yes install libssl-dev
eval $proxy apt-get -y --force-yes install zlib1g-dev

# Set ruby 1.9 as the default alternative
eval $proxy update-alternatives --install /usr/bin/ruby ruby /usr/bin/ruby1.9.1 400 \
 --slave   /usr/share/man/man1/ruby.1.gz ruby.1.gz /usr/share/man/man1/ruby1.9.1.1.gz \
 --slave   /usr/bin/ri ri /usr/bin/ri1.9.1 \
 --slave   /usr/bin/irb irb /usr/bin/irb1.9.1 \
 --slave   /usr/bin/rdoc rdoc /usr/bin/rdoc1.9.1

eval $proxy update-alternatives --set ruby /usr/bin/ruby1.9.1
eval $proxy update-alternatives --set gem /usr/bin/gem1.9.1
# ================================== 

# ================================ PUPPET INSTALLATION ============================
echo "Installing puppet"
# Get server OS release version
release=$(lsb_release -cs)
# Get puppet install package
eval $proxy wget http://apt.puppetlabs.com/puppetlabs-release-$release.deb -O /tmp/puppetlabs-release-$release.deb
# Install puppetlab package 
eval $proxy dpkg -i /tmp/puppetlabs-release-$release.deb
# Update/Re-sync packages index (to reflect new puppet enabled package)
eval $proxy apt-get update

# Install puppet tool
eval $proxy apt-get -y --force-yes -o Dpkg::Options::="--force-confnew" install puppet
# ==================================


# ================================== Puppet librarian ==============================
[ $release == "precise" ] && eval $proxy apt-get -y --force-yes install rubygems1.9.1 || :
eval $proxy apt-get -y --force-yes install git
eval $proxy gem install librarian-puppet -v 1.0.3
# ==================================

[ -f /etc/apt/sources.list.d/puppetlabs.list ] && rm /etc/apt/sources.list.d/puppetlabs.list || :
