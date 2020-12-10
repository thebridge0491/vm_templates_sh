#!/bin/sh -eux

## scripts/upgradepkgs.sh
set +e

pkg_add -u
pkg_add sudo--

# #?? clean
DEVX=${DEVX:-sd0}
#fsck_ffs /dev/${DEVX}a
#fsck_ffs /dev/${DEVX}d
sync
