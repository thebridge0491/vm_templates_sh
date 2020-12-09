#!/bin/sh -eux

## scripts/upgradepkgs.sh
set +e

apk update ; apk fix ; apk upgrade -U -a
apk add file sudo openssl
# ?? how to display held/pinned packages ??

mkdir -p /var/cache/apk ; ln -s /var/cache/apk /etc/apk/cache
apk -v cache clean
if command -v zpool > /dev/null ; then
  ZPOOLNM=${ZPOOLNM:-ospool0} ;
  zpool trim ${ZPOOLNM} ; zpool set autotrim=on ${ZPOOLNM} ;
else
  fstrim -av ;
fi
sync
