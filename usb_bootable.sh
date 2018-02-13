#!/bin/bash

set -o xtrace

# Script creates a bootable usb key from an ISO image

# Common variables
_DLUX_REPO="https://raw.githubusercontent.com/dlux/InstallScripts/master"
_DIR=/opt/_usb_stick
_URL="$1"
_DEVICE="$2"
_SHA256SUMS="$3"

# Setup
if [[ ! -f common_packages ]]; then
    curl -O $_DLUX_REPO/common_functions
    curl -O $_DLUX_REPO/common_packages
fi

[[ ! -f common_packages ]] && echo "Error downloading common_packages" && exit 1 || source common_packages

EnsureRoot
SetLocale /root

UpdatePackageManager

if [[ -z $_URL || -z $_DEVICE ]];then
    msg="\nUsage: usb_bootable 'http://anyUrl/imageX.iso' '/dev/sdb1' 'SHA256SUMS_file'\n"
    msg=${msg}"Positional Arguments: URL, device and Optionally sha256sumsFILENAME\n\n"
    msg=${msg}"Error - missing positional argument: URL"
    PrintError "$msg"
fi

echo "<<=================== Start processing ===============================>>"
mkdir -p $_DIR
pushd $_DIR
echo "<<------------ Getting ISO from $_URL------"
curl -vO $_URL

# Get sums file using same base URL
echo "<<------------ Check ISO data integrity -------"
if [[ -n $_SHA256SUMS ]]; then
    curl -vO $(echo ${_URL%/*})/$_SHA256SUMS
    _img_name=$(echo $_URL | sed 's/.*\///g')
    [[ ! -f "$_SHA256SUMS" ]] && PrintError "Unable to process $_SHA256SUMS"
    data=$(sha256sum -c <(grep "${_img_name}" $_SHA256SUMS))
    [[ -z $(echo $data | grep -i ":.ok") ]] && PrintError "ISO data is corrupted."
fi

[[ ! -b $_DEVICE ]] && PrintError "Device $_DEVICE does not exist."
echo "<<------------ Burning USB bootable stick --------"
dd if="${_img_name}" of= bs=16m
popd

# Some repo iso URLs
# http://releases.ubuntu.com/16.04.3/ubuntu-16.04.3-server-amd64.iso
