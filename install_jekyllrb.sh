#!/bin/bash

# ============================================================================
# Post-install setup.
# Script installs ruby, apache, jekyllrb and its dependencies.
# Assume: Ubuntu distro.
# ============================================================================


# Uncomment the following line to debug this script
# set -o xtrace

# ================== Processes Functions =====================================

INSTALL_DIR=$(cd $(dirname "$0") && pwd)
_release=''
_apache=false

source $INSTALL_DIR/common_packages

function _PrintHelp {
    installTxt="Install and configure jekyllrb"
    scriptName=$(basename "$0")
    opts="     --apache  | -a    Install apache server. Defaults to port 80."
    opts="$opts     --release  | -r     Install given ruby release."
    PrintHelp "${installTxt}" "${scriptName}" "${opts}"
}

# ================== Processes script options ================================

EnsureRoot

while [[ ${1} ]]; do
  case "${1}" in
    --apache|-a)
      _apache=true
      ;;
    --release|-r)
      msg="Missing release."
      if [[ -z $2 ]]; then PrintError "${msg}"; else _release="${2}"; fi
      shift
      ;;
    --help|-h)
      _PrintHelp
      ;;
    *)
      HandleOptions "$@"
      shift
  esac
  shift
done

# ================== Installation ===========================================

# Install development tools
eval $_PROXY apt-get update
eval $_PROXY apt-get install -y wget curl unzip git
eval $_PROXY apt-get install -y build-essential libssl-dev libffi-dev libxml2-dev
eval $_PROXY apt-get install -y libxslt1-dev libpq-dev

# Ruby
if [[ -z "$_release" ]]; then
    eval $_PROXY apt-get install -y ruby ruby-dev ruby-full
else
    eval $_PROXY apt-get install -y ruby"$_release" ruby-dev"$_release"
fi

if [[ $_apache == true ]]; then
    eval $_PROXY InstallApache
    CustomizeApache
fi

eval $_PROXY gem install jekyll bundler

# Get example website and deploy
eval $_PROXY git clone https://github.com/dlux/blog_project.git
cd blog_project/dashboard/

if [[ $_apache == true ]]; then
    jekyll build -d /var/www/html/dashboard
    echo "Goto http://localhost/dashboard"
else
    bundle exec jekyll serve
    echo "Goto http://localhost:4000/"
fi

echo "Installation Completed Successfully"
echo "Modify blog_project/dashboard/_config.yml"
echo "See: https://jekyllrb.com/docs/"

