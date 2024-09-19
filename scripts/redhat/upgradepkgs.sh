#!/bin/sh -eux

## scripts/upgradepkgs.sh
set +e

dnf -y check-update ; dnf -y upgrade
dnf --setopt=install_weak_deps=False -y install @core dnf-plugins-core yum-utils sudo openssl
dnf versionlock list ; sleep 3

distro="$(rpm -qf --queryformat '%{NAME}' /etc/redhat-release | cut -f 1 -d '-')"
if [ "${distro}" != 'redhat' ] ; then
  dnf -y clean all ;
fi

. /etc/os-release
snapshot_name=${ID}_${VERSION_ID}-$(date -u "+%Y%m%d")

if command -v zpool > /dev/null ; then
  ZPOOLNM=${ZPOOLNM:-ospool0} ;

  zfs snapshot ${ZPOOLNM}/ROOT/default@${snapshot_name} ;
  # example remove: zfs destroy ospool0/ROOT/default@snap1

  zfs list -t snapshot ; sleep 5 ;
  zpool trim ${ZPOOLNM} ; zpool set autotrim=on ${ZPOOLNM} ;
else
  if command -v lvcreate > /dev/null ; then
    GRP_NM=${GRP_NM:-vg0} ;

    lvcreate --snapshot --size 2G --name ${snapshot_name} ${GRP_NM}/osRoot ;
    # example remove: lvremove vg0/snap1

    lvs ; sleep 5 ;
  fi ;
  fstrim -av ;
fi
sync
