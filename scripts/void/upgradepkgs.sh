#!/bin/sh -eux

## scripts/upgradepkgs.sh
set +e

xbps-install -S ; xbps-install -y -u
xbps-install -y file sudo libressl
xbps-query --list-hold-pkgs ; sleep 3

xbps-remove -O
if command -v zpool > /dev/null ; then
  ZPOOLNM=${ZPOOLNM:-ospool0} ;
  zpool trim ${ZPOOLNM} ; zpool set autotrim=on ${ZPOOLNM} ;
else
  fstrim -av ;
fi
sync
