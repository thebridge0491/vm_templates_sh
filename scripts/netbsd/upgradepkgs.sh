#!/bin/sh -eux

## scripts/upgradepkgs.sh
set +e

pkgin update ; pkgin -y upgrade ; pkgin -y full-upgrade #pkg_add -u
pkgin -y install sudo #pkg_add sudo

pkgin -y clean # #?? clean
DEVX=${DEVX:-sd0} ; GRP_NM=${GRP_NM:-bsd1}
dkRoot=$(dkctl ${DEVX} listwedges | grep -e "${GRP_NM}-fsRoot" | cut -d: -f1)
dkVar=$(dkctl ${DEVX} listwedges | grep -e "${GRP_NM}-fsVar" | cut -d: -f1)
#fsck_ffs /dev/${dkRoot}
#fsck_ffs /dev/${dkVar}
sync
