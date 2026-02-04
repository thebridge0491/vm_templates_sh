#!/bin/sh -eux

## scripts/upgradepkgs.sh
set +e

fetch_distrosets() {
  # xbase xserver xfont xetc
  distrosets=${distrosets:-xbase}

  read -p "Extract after fetch distribution components/sets? Enter 'y' to continue [yN]: " response
  # fetch distribution sets like: xbase.tar.xz
  # uname_m: [amd64 | arm64] ; rel: X.Y
  uname_m=$(uname -m) ; rel=$(sysctl -n kern.osrelease)
  cd /tmp
  for setX in ${distrosets} ; do
    ftp http://cdn.netbsd.org/pub/NetBSD/NetBSD-${rel}/${uname_m}/binary/sets/${setX}.tar.xz ;
    if [ "y" = "${response}" ] || [ "Y" = "${response}" ] ; then
      tar -C / -xpJf ${setX}.tar.xz ;
    fi ;
  done
}

run_upgradepkgs() {
  pkgin update

  tail -vn+1 /usr/pkg/etc/pkgin/repositories.conf | grep -ve "^#" ; sleep 5
  pkgin -l\< list

  read -p "Enter 'y' to continue [yN]: " response
  #if [ ! "y" = "${response}" ] && [ ! "Y" = "${response}" ] ; then
  if [ -z "$(echo ${response} | grep -e '^[Yy].*')" ] ; then
    exit ;
  fi
  pkgin -y upgrade ; pkgin -y full-upgrade #; pkg_add -u

  #pkg_add pkg0 .. pkgN # OK, skips missing
  #pkgin [-d] -y install pkg0 .. pkgN # OK, skips missing
  pkgin -y install pkgUnknown nano pkgMissing zip
  #for pkgX in pkgUnknown nano pkgMissing zip ; do
  #  pkgin -y install ${pkgX} ;
  #done

  DEVX=${DEVX:-sd0} ; GRP_NM=${GRP_NM:-nbsd1}
  dkRoot=$(dkctl ${DEVX} listwedges | grep -e "${GRP_NM}-fsRoot" | cut -d: -f1)
  dkVar=$(dkctl ${DEVX} listwedges | grep -e "${GRP_NM}-fsVar" | cut -d: -f1)
  #fsck_ffs /dev/${dkRoot}
  #fsck_ffs /dev/${dkVar}
  sync

  pkgin -y clean # #?? clean
}

#----------------------------------------
${@:-run_upgradepkgs}
