#!/bin/sh -eux

## scripts/upgradepkgs.sh
set +e

fetch_distrosets() {
  # xbase xserv xfont xshare
  distrosets=${distrosets:-xbase}

  read -p "Extract after fetch distribution components/sets? Enter 'y' to continue [yN]: " response
  # fetch distribution sets like: xbase*.tgz
  # arch_s: [amd64 | arm64] ; rel: X.Y
  arch_s=$(arch -s) ; rel=$(sysctl -n kern.osrelease)
  setVer=$(sysctl -n kern.osrelease | tr '.' '\0')
  cd /tmp
  for setX in ${distrosets} ; do
    ftp http://cdn.openbsd.org/pub/OpenBSD/${rel}/${arch_s}/${setX}${setVer}.tgz ;
    if [ "y" = "${response}" ] || [ "Y" = "${response}" ] ; then
      tar -C / -xpzf ${setX}${setVer}.tgz ;
    fi ;
  done

  if [ "y" = "${response}" ] || [ "Y" = "${response}" ] ; then
    sysmerge ;
  fi
}

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


  DEVX=${DEVX:-sd0}
  #fsck_ffs /dev/${DEVX}a
  #fsck_ffs /dev/${DEVX}d
  sync

  # #?? clean
}

#----------------------------------------
${@:-run_upgradepkgs}
