#!/bin/sh -eux

## scripts/upgradepkgs.sh
set +e

if command -v systemctl > /dev/null ; then
  systemctl stop pamac.service ;
elif command -v rc-update > /dev/null ; then
  rc-service pamac stop ;
elif command -v sv > /dev/null ; then
  sv down pamac ;
elif command -v s6-rc > /dev/null ; then
  s6-rc -d change pamac ;
fi
rm /var/lib/pacman/db.lck
set -e
pacman --noconfirm -Syy ; pacman --noconfirm -Syu
pacman --noconfirm --needed -S base which sudo
grep -e '^IgnorePkg' /etc/pacman.conf ; sleep 3

pacman --noconfirm -Sc

if [ -f /etc/os-release ] ; then
  . /etc/os-release ;
elif [ -f /usr/lib/os-release ] ; then
  . /usr/lib/os-release ;
fi
snapshot_name=${ID}_upgrade-$(date -u "+%Y%m%d")

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
