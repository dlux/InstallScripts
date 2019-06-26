#!/bin/bash

# Description: Install a different kernel on current OS
# Procedure:
#   1. Get desired newkernelversion.rpm
#   2. Install the new_kernel_version.rpm using cpio tool.
#   3. Set new kernel as the default boot option
#   4. Verify  kernel version

KERNEL_NAME=“”
KERNEL_VERSION=“”
KERNEL_FILE=""

PrintError (){
    echo "Error: $1"
    exit 1
}

[[ $UID != 0 ]] && PrintError ‘Must run as root.’

[[ -z "$1" ]] && PrintError 'Must provide kenel name.' || KERNEL_NAME="$1"
[[ -z "$2" ]] && PrintError 'Must provide kenel version' || KERNEL_VERSION="$2"

KERNEL_ID="${KERNEL_NAME}${KERNEL_VERSION}"
source /etc/os-release
[[ $ID_LIKE =~ 'rhel' ]] && ext='rpm' || ext='deb'

[[ -n "$3" ]] && KERNEL_FILE="$3" || KERNEL_FILE="${KERNEL_ID}.${ext}"
[[ ! -f $KERNEL_FILE ]] && PrintError ‘Missing new kernel file’

InstallKernelRHEL (){
    rpm2cpio $KERNEL_FILE | cpio -idmv
    cp -rf ./lib/modules/$nkid /usr/lib/modules/

    # Install kernel
    cd boot
    installkernel $KERNEL_ID vmlinuz-${KERNEL_ID} System.map-${KERNEL_ID}
    # Update grub
    grub2-mkconfig -o /boot/efi/EFI/centos/grub.cfg
    echo "Changes completed"
    echo "Reboot system"
    echo "After reboot, verify kernel with command 'uname -a'"
}

VerifyKernel () {
    uname -a | grep $KERNEL_ID
}

[[ $ID_LIKE =~ 'rhel' ]] && InstallKernelRHEL

