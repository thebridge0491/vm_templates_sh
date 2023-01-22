#!/bin/sh -eux

## scripts/upgradepkgs.sh
set +e

xbps-install -S ; xbps-install -y -u
xbps-install -y file sudo openssl
xbps-query --list-hold-pkgs ; sleep 3

xbps-remove -O
if command -v zpool > /dev/null ; then
  ZPOOLNM=${ZPOOLNM:-ospool0} ;
  zpool trim ${ZPOOLNM} ; zpool set autotrim=on ${ZPOOLNM} ;

  zfs list -t snapshot ; sleep 5 ;
else
  fstrim -av ;
  if command -v btrfs > /dev/null ; then
    btrfs subvolume list / ;
  elif command -v lvcreate > /dev/null ; then
    lvs ;
  fi ;
  sleep 5 ;
fi
sync
