#!/bin/sh -eux

## scripts/upgradepkgs.sh
set +e

run_upgradepkgs() {
  tail -n+1 . /etc/installurl | grep -ve "^#" ; sleep 5
  #pkg_version -vIL=
  #pkg_version -l\<
  pkg_add -n -u

  read -p "Enter 'y' to continue [yN]: " response
  #if [ ! "y" = "${response}" ] && [ ! "Y" = "${response}" ] ; then
  if [ -z "$(echo ${response} | grep -e '^[Yy].*')" ] ; then
    exit ;
  fi
  #pkg_add -n -u
  pkg_add -u

  #pkg_add [-n] -ziU pkg0-- .. pkgN-- # OK, skips missing
  pkg_add -ziU pkgUnknown-- nano-- pkgMissing-- zip--
  #for pkgX in pkgUnknown-- nano-- pkgMissing-- zip-- ; do
  #  pkg_add -ziU ${pkgX} ;
  #done

  # #?? clean

  DEVX=${DEVX:-sd0}
  #fsck_ffs /dev/${DEVX}a
  #fsck_ffs /dev/${DEVX}d
  sync
}

#----------------------------------------
${@:-run_upgradepkgs}
