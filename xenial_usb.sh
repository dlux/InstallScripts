#!/bin/bash
set -e
set -o xtrace

apt-get update
apt-get install wget curl gpg gpg2

mkdir ubuntuStick
pushd ubuntuStick

# Get ISO Ubuntu Server 16.04 LTS
wget https://www.ubuntu.com/download/server/thank-you?version=16.04.2&architecture=amd64

# Verify iso
# Get sums
wget http://releases.ubuntu.com/16.04/SHA256SUMS
wget http://releases.ubuntu.com/16.04/SHA256SUMS.gpg
# Get public keys from ubuntu
gpg --keyserver hkp://keyserver.ubuntu.com --recv-keys "8439 38DF 228D 22F7 B374 2BC0 D94A A3F0 EFE2 1092" "C598 6B4F 1257 FFA8 6632 CBA7 4618 1433 FBB7 5451"
# Verify the key fingerprints.
gpg --list-keys --with-fingerprint 0xFBB75451 0xEFE21092
# Verify the signature
gpg --verify SHA256SUMS.gpg SHA256SUMS

# Check ISO
sha256sum -c SHA256SUMS 2>&1 | grep OK


popd
