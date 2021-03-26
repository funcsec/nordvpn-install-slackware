#!/usr/bin/env bash

# Excellent bash template
# from https://betterdev.blog/minimal-safe-bash-script-template/

set -Eeuo pipefail
trap cleanup SIGINT SIGTERM ERR EXIT

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)

usage() {
  cat <<EOF
Usage: $(basename "${BASH_SOURCE[0]}") [-h] [-v]

Install Nordvpn on Slackware via SlackBuild

Available options:

-h, --help      Print this help and exit
-v, --verbose   Print script debug info

Version 1.1.3
EOF
  exit
}

cleanup() {
  trap - SIGINT SIGTERM ERR EXIT
  rm /tmp/nordvpn.tar.gz
  rm -rf /tmp/nordvpn
}


setup_colors() {
  if [[ -t 2 ]] && [[ -z "${NO_COLOR-}" ]] && [[ "${TERM-}" != "dumb" ]]; then
    NOFORMAT='\033[0m' RED='\033[0;31m' GREEN='\033[0;32m' ORANGE='\033[0;33m' BLUE='\033[0;34m' PURPLE='\033[0;35m' CYAN='\033[0;36m' YELLOW='\033[1;33m'
  else
    NOFORMAT='' RED='' GREEN='' ORANGE='' BLUE='' PURPLE='' CYAN='' YELLOW=''
  fi
}

msg() {
  echo >&2 -e "${1-}"
}

die() {
  local msg=$1
  local code=${2-1} # default exit status 1
  msg "$msg"
  exit "$code"
}

parse_params() {
  # default values of variables set from params
  flag=0
  param=''

  while :; do
    case "${1-}" in
    -h | --help) usage ;;
    -v | --verbose) set -x ;;
    --no-color) NO_COLOR=1 ;;
    -?*) die "Unknown option: $1" ;;
    *) break ;;
    esac
    shift
  done


  # check required params and arguments

  return 0
}

parse_params "$@"
setup_colors

msg "================================================================================"
msg "Changing directory to /tmp"
msg "================================================================================"

cd /tmp                                                                       

msg "================================================================================"
msg "Downloading Nordvpn build from SlackBuilds"
msg "================================================================================"

wget https://slackbuilds.org/slackbuilds/14.2/network/nordvpn.tar.gz          
tar -xzf nordvpn.tar.gz                                                       
cd nordvpn                                                                    

msg "================================================================================"
msg "Downloading Nord RPM"
msg "================================================================================"

SRC=`awk -F "\"" '/DOWNLOAD_x86_64/ {print $2}' nordvpn.info`
FILENAME=`echo $SRC | awk -F "/" '{print $NF}'`
INSTALL=`echo $FILENAME | sed 's/\.[^.]*$//'`
echo "$SRC" | xargs -n1 wget

msg "================================================================================"
msg "Verifying MD5 sum"
msg "================================================================================"

echo `awk -F "\"" '/MD5SUM_x86_64/ {print $2}' nordvpn.info` "$FILENAME" | md5sum --check

msg "================================================================================"
msg "Building package"
msg "================================================================================"

cd /tmp/nordvpn
chmod +x ./nordvpn.SlackBuild                                                 
./nordvpn.SlackBuild                                                          

msg "================================================================================"
msg "Installing package"
msg "================================================================================"

INSTALLALT=`echo "$INSTALL" | awk -F "-" '{print $1"-"$2"-"substr($3, 3)$4}'`

INSTALLER="/tmp/$INSTALL-1_SBo.tgz"
INSTALLERALT="/tmp/$INSTALLALT-1_SBo.tgz"

if [ -f "$INSTALLER" ]; then
    installpkg "$INSTALLER"
elif [ -f "$INSTALLERALT" ]; then
    installpkg "$INSTALLERALT"
else
    msg "Oh no! I can not find the installer in /tmp/"
    msg "It might be there but at a filename I can not predict"
    msg "Check for $INSTALL-????.tgz in /tmp/"
    msg "Run it with:"
    msg "installpkg FILEPATH"
    msg "Change FILEPATH to the absolute path of the file you found"
    die "Unable to find $INSTALLER or $INSTALLERALT"
fi

chmod +x /etc/rc.d/rc.nordvpn

msg "================================================================================"
msg "SUCCESS!!"
msg "================================================================================"

msg ""
msg "Start NordVPN daemon with:"
msg "/etc/rc.d/rc.nordvpn start"

msg ""
msg "Stop NordVPN daemon with:"
msg "/etc/rc.d/rc.nordvpn stop"

msg ""
msg "Access nordvpn help with:"
msg "nordvpn --help"
msg ""
     
