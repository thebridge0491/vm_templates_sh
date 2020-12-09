#!/bin/sh -eux

## scripts/upgradepkgs.sh
set +e

if command -v systemctl > /dev/null ; then
  systemctl stop pamac ;
elif command -v rc-update > /dev/null ; then
  rc-service pamac stop ;
fi
rm /var/lib/pacman/db.lck
set -e
pacman --noconfirm -Syy ; pacman --noconfirm -Syu
pacman --noconfirm --needed -S base which sudo
grep -e '^IgnorePkg' /etc/pacman.conf ; sleep 3

pacman --noconfirm -Sc
if command -v zpool > /dev/null ; then
  ZPOOLNM=${ZPOOLNM:-ospool0} ;
  zpool trim ${ZPOOLNM} ; zpool set autotrim=on ${ZPOOLNM} ;
else
  fstrim -av ;
fi
sync
