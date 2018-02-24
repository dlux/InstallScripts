#!/bin/bash

# Uncomment line to debug
set -o xtrace

[[ ! -f common_functions ]] && curl -O \
  https://raw.githubusercontent.com/dlux/InstallScripts/master/common_functions
[[ ! -f common_functions ]] && exit 1
source common_functions

EnsureRoot
SetLocale /root
umask 022

if [[ $(isUbuntu) == True ]]; then
    apt-get update
    apt-get install -y software-properties-common
    apt-add-repository -y ppa:ansible/ansible
    apt-get update
    apt-get install -y ansible
else
    yum install -y epel-release
    yum install -y --enablerepo="epel" ansible
fi
