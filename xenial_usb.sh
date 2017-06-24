#!/bin/bash

source common_functions

EnsureRoot
SetLocale /root

# Handle standard options if any (domain, proxy, and help)
while [[ ${1} ]]; do
  case "${1}" in
    *)
      HandleOptions "$@"
      shift
  esac
  shift
done

eval $_PROXY apt-get update
eval $_PROXY apt-get -y install wget gnupg2

_dir=/opt/ubuntu_usb_stick
_img_version="16.04.2"
_img_arch="amd64"
_img_name="ubuntu-${_img_version}-server-${_img_arch}.iso"
mkdir -p $_dir
pushd $_dir

echo ================ Get ISO Ubuntu Server 16.04 LTS ========================
wget "https://www.ubuntu.com/download/server/thank-you?version=${_img_version}&architecture=${_img_arch}"

# Get sums
eval $_PROXY wget http://releases.ubuntu.com/"${_img_version}"/SHA256SUMS -P $_dir
eval $_PROXY wget http://releases.ubuntu.com/"${_img_version}"/SHA256SUMS.gpg -P $_dir

echo ================ Verify signature do not match ===================================
gpg --verify SHA256SUMS.gpg SHA256SUMS

echo ================ Obtain public key from Ubuntu server ===================
eval $_PROXY gpg --keyserver hkp://keyserver.ubuntu.com --recv-keys 0xFBB75451 0xEFE21092

echo ================ Verify fingerprints ====================================
eval $_PROXY gpg --list-keys --with-fingerprint 0xFBB75451 0xEFE21092

echo ================ Verify signature again =================================
eval $_PROXY gpg --verify SHA256SUMS.gpg SHA256SUMS

echo ================ Check the ISO ==========================================
sha256sum -c <(grep "${_img_name}" SHA256SUMS)

device_name=$(lsusb -D)
if [[ ! -z $device_name ]]; then
    echo "================ Burning USB bootable stick ========================"
    dd if="${_img_name}" of=$device_name bs=16M
fi

popd

