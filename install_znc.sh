#!/bin/bash

# ============================================================================
# @revision V.1.1
# @author: luzC
# @brief: Script installs and configure znc - IRC bouncer server.
#         Assume Ubuntu distribution.
# ============================================================================

# Uncomment the following line to debug this script
# set -o xtrace
#=================================================
# GLOBAL VARIABLES DEFINITION
#=================================================
_ORIGINAL_PROXY=''
_PROXY=''
_APTF=''
_DOMAIN=',.intel.com'
_IP_ADD=''
_RELEASE='1.6.5'

#=================================================
# GLOBAL FUNCTIONS
#=================================================
# Error Function
function PrintError {
    echo "************************************" >&2
    echo "* $(date +"%F %T.%N") ERROR: $1" >&2
    echo "************************************" >&2
    exit 1
}

function PrintHelp {
    echo " "
    echo "Script installs and configure znc IRC bouncer." \
" Optionally accepts proxy server - to be handled by proxychains."
    echo " "
    echo "Usage:"
    echo "./install_znc.sh [--proxy | -x <http://server:port>]" \
"[--release <max.min.x>]"
    echo " "
    echo "     --proxy   | -x   Uses the given proxy for the configuration."
    echo "     --release | -r   Install given znc release. Default to 1.6.5."
    echo "     --help           Prints current help text. "
    echo " "
    exit 1
}

function ValidateIP {
    local  ip="$1"
    local  stat=1

    if [[ $ip =~ ^([0-9]{1,3}.){3}([0-9]{1,3})$ ]]; then
        # Save current shell delimiter
        oifs=$IFS
        # Use dot as new delimeter
        IFS='.'
        # Create array (dot delimeter)
        ip=($ip)
        # return delimiter to its original state
        IFS=$oifs
        # verify IP address is valid
        [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 \
            && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
        stat=$?
    fi

    [[ $stat -eq 1 ]] && PrintError "Invalid IP address: $1"
}

function GetIP {
    [[ -z $1 ]] && PrintError "Missing proxy url."

    svr=$(echo $1 | cut -d':' -f2 | sed s-//--g)
    _IP_ADD=$(getent hosts $svr | grep -oE "([0-9]{1,3}.){3}[0-9]{1,3}")

    ValidateIP $_IP_ADD
}

# ====================== Processes installation options ======================
while [[ ${1} ]]; do
case "${1}" in
    --proxy|-x)
        [[ -z "${2}" || "${2}" == -* ]] && PrintError "Missing proxy data."

        _ORIGINAL_PROXY="${2}"
        # Get proxy IP address
        GetIP $_ORIGINAL_PROXY

        # Set proxy for apt repositories
        _file='/etc/apt/apt.conf'
        [[ -f $_file ]] && _APTF="$_file" || _APTF="${_file}.d/70proxy.conf"
        echo "Acquire::http::Proxy \"${2}\";" | sudo tee -a $_APTF

        # set vars
        npx="127.0.0.0/8,localhost,10.0.0.0/8,192.168.0.0/16${_DOMAIN}"
        _PROXY="http_proxy=${2} https_proxy=${2} no_proxy=${npx}"
        _PROXY="$_proxy HTTP_PROXY=${2} HTTPS_PROXY=${2} NO_PROXY=${npx}"

        shift
        ;;
    --release|-r)
        [[ -z "${2}" || "${2}" == -* ]] && PrintError "Missing release number."
        _RELEASE="${2}"
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
# ============================================================================
# BEGIN PACKAGE INSTALATION
# Ensure script is run as NO root
[[ "$EUID" -eq "0" ]] && PrintError "This script must NOT be run as root."

# Install development tools
eval $_PROXY sudo -E apt-get update
eval $_PROXY sudo -E apt-get install -y build-essential \
automake autoconf pkg-config swig3.0 \
libssl-dev libffi-dev libpq-dev libperl-dev libicu-dev

# Process tarball only if znc not installed
if [[ ! -f /usr/local/bin/znc && ! -f /usr/local/lib/znc ]]; then
    znc_tar="znc-${_RELEASE}.tar.gz"
    echo "Processing $znc_tar tarball to install ZNC"

    eval $_PROXY curl -O https://znc.in/releases/archive/$znc_tar
    [[ ! -f $znc_tar ]] && PrintError "Unable to download znc tarball."
    tar -xzvf $znc_tar
    rm -f $znc_tar

    pushd znc-${_RELEASE}
    # compile & install
    ./configure
    make
    sudo make install

    # Create config file -- REQUIRES MANUAL INPUT
    znc --makeconf
    echo "ZNC installed and configured!!"
    sleep 1
    popd
fi

# If behind proxy - use proxychains and re-run znc under it
if [[ ! -z "${_PROXY}" ]]; then
    eval $_PROXY sudo -E apt-get install -y proxychains

    # Modify default proxy settings
    sudo sed -i 's/socks4/\#socks4/g' /etc/proxychains.conf
    sudo sed -i "/^\[ProxyList/ a socks5 $_IP_ADD  1080" /etc/proxychains.conf
    sleep 1
    # Restart znc
    process_num=$(pgrep -f "znc --makeconf" || pgrep -f "^znc$")
    if [[ -n $process_num ]]; then
        echo "Stopping current znc process $process_num"
        pkill -SIGUSR1 -s $process_num
        pkill -s $process_num
        sleep 1
    fi
    msg='ZNC Restarted under Proxychains.'
    proxychains znc
    [[ $? -eq 0 ]] && echo "$msg" || echo "Error: Something went wrong"
fi

# Cleanup _PROXY from apt if added - first coincedence
if [[ ! -z "${_ORIGINAL_PROXY}" ]]; then
    scaped_str=$(echo $_ORIGINAL_PROXY | sed -s 's/[\/&]/\\&/g')
    sudo sed -i "0,/$scaped_str/{/$scaped_str/d;}" $_APTF
fi
