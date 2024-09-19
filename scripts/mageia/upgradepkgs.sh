#!/bin/sh -eux

## scripts/upgradepkgs.sh
MIRROR=${MIRROR:-mirror.math.princeton.edu/pub/mageia}

set +e

#urpmq --list-url ; sleep 5
#urpmi.update -a ; urpmi --auto-update
dnf repolist enabled ; sleep 5
dnf -y check-update ; dnf -y upgrade
#urpmi --no-recommends sudo
dnf -y --setopt=install_weak_deps=False install sudo
dnf versionlock list ; sleep 3

dnf -y clean all

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
