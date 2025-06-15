#!/bin/sh -eux

## scripts/upgradepkgs.sh
set +e

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

  pkgin -y clean # #?? clean

  DEVX=${DEVX:-sd0} ; GRP_NM=${GRP_NM:-nbsd1}
  dkRoot=$(dkctl ${DEVX} listwedges | grep -e "${GRP_NM}-fsRoot" | cut -d: -f1)
  dkVar=$(dkctl ${DEVX} listwedges | grep -e "${GRP_NM}-fsVar" | cut -d: -f1)
  #fsck_ffs /dev/${dkRoot}
  #fsck_ffs /dev/${dkVar}
  sync
}

#----------------------------------------
${@:-run_upgradepkgs}
