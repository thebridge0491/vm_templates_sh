#!/bin/sh -eux

## scripts/upgradepkgs.sh
set +e

apk update ; apk fix ; apk upgrade -U -a
apk add file sudo openssl
# ?? how to display held/pinned packages ??

mkdir -p /var/cache/apk ; ln -s /var/cache/apk /etc/apk/cache
apk -v cache clean

. /etc/os-release
snapshot_name=${ID}_${VERSION_ID}-$(date -u "+%Y%m%d")

if command -v zpool > /dev/null ; then
  ZPOOLNM=${ZPOOLNM:-ospool0} ;

  zfs snapshot ${ZPOOLNM}/ROOT/default@${snapshot_name} ;
  # example remove: zfs destroy ospool0/ROOT/default@snap1

  zfs list -t snapshot ; sleep 5 ;
  zpool trim ${ZPOOLNM} ; zpool set autotrim=on ${ZPOOLNM} ;
else
  if command -v btrfs > /dev/null ; then
    btrfs subvolume snapshot / /.snapshots/${snapshot_name} ;
    # example remove: btrfs subvolume delete /.snapshots/snap1

    btrfs subvolume list / ; sleep 5 ;
  elif command -v lvcreate > /dev/null ; then
    GRP_NM=${GRP_NM:-vg0} ;

    lvcreate --snapshot --size 2G --name ${snapshot_name} ${GRP_NM}/osRoot ;
    # example remove: lvremove vg0/snap1

    lvs ; sleep 5 ;
  fi ;
  fstrim -av ;
fi
sync
