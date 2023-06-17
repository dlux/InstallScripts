#!/bin/bash

# ============================================================================
# Post-install setup.
# Script installs ruby, apache, jekyll and its dependencies.
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
    installTxt="Install and configure jekyll"
    scriptName=$(basename "$0")
    opts="     --apache  | -a    Install apache server. Defaults to port 80."
    opts="$opts     --ruby-release  | -r     Install given ruby release."
    PrintHelp "${installTxt}" "${scriptName}" "${opts}"
}

# ================== Processes script options ================================

EnsureRoot

while [[ ${1} ]]; do
    case "${1}" in
    --apache|-a)
        _apache=true
        ;;
    --ruby-release|-r)
        msg="Missing release."
        [[ -z $2 ]] && PrintError "${msg}" || _release="${2}"
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
eval $_PROXY apt-get install -y wget curl unzip git build-essential zlib1g-dev

# Install Ruby
if [[ -z "$_release" ]]; then
    eval $_PROXY apt-get install -y ruby-full
else
    eval $_PROXY apt-get install -y ruby"$_release" ruby-dev"$_release"
fi

if [[ $_apache == true ]]; then
    eval $_PROXY InstallApache
    CustomizeApache
fi

eval $_PROXY gem install jekyll bundler

# Get example website and deploy
#eval $_PROXY git clone https://github.com/dlux/blog_project.git
#cd blog_project/dashboard/

#if [[ $_apache == true ]]; then
#    jekyll build -d /var/www/html/dashboard
#    echo "Goto http://localhost/dashboard"
#else
#    bundle exec jekyll serve
#    echo "Goto http://localhost:4000/"
#fi

echo "Installation Completed Successfully"
echo "See: https://jekyllrb.com/docs/"

