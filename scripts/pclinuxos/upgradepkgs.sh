#!/bin/sh -eux

## scripts/upgradepkgs.sh
MIRROR=${MIRROR:-spout.ussg.indiana.edu}

os_version=$(grep VERSION= /etc/os-release | cut -f2 -d\" | cut -f1 -d\ )

set +e

grep -e '^rpm.*' /etc/apt/sources.list ; sleep 5
apt-get -y update
apt-get -y --fix-broken install
apt-get -y upgrade ; apt-get -y dist-upgrade
apt-get -y --option Retries=3 install sudo
grep -e '^Hold' /etc/apt/apt.conf

apt-get -y clean
if command -v zpool > /dev/null ; then
  ZPOOLNM=${ZPOOLNM:-ospool0} ;
  zpool trim ${ZPOOLNM} ; zpool set autotrim=on ${ZPOOLNM} ;
else
  fstrim -av ;
fi
sync
