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

. /etc/os-release
snapshot_name=${ID}_${VERSION}-$(date -u "+%Y%m%d")

if command -v btrfs > /dev/null ; then
  btrfs subvolume snapshot / /.snapshots/${snapshot_name} ;
  # example remove: btrfs subvolume delete /.snapshots/snap1

  btrfs subvolume list / ; sleep 5 ;
elif command -v lvcreate > /dev/null ; then
  GRP_NM=${GRP_NM:-vg0} ;

  lvcreate --snapshot --size 2G --name ${snapshot_name} ${GRP_NM}/osRoot ;
  # example remove: lvremove vg0/snap1

  lvs ; sleep 5 ;
fi
fstrim -av
sync
