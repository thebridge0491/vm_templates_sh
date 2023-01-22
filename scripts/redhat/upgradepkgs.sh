#!/bin/sh -eux

## scripts/upgradepkgs.sh
set +e

dnf -y check-update ; dnf -y upgrade
dnf --setopt=install_weak_deps=False -y install @core dnf-plugins-core yum-utils sudo openssl
dnf versionlock list ; sleep 3

distro="$(rpm -qf --queryformat '%{NAME}' /etc/redhat-release | cut -f 1 -d '-')"
if [ "$distro" != 'redhat' ] ; then
  dnf -y clean all ;
fi
if command -v zpool > /dev/null ; then
  ZPOOLNM=${ZPOOLNM:-ospool0} ;
  zpool trim ${ZPOOLNM} ; zpool set autotrim=on ${ZPOOLNM} ;

  zfs list -t snapshot ; sleep 5 ;
else
  fstrim -av ;
  if command -v lvcreate > /dev/null ; then
    lvs ;
  fi ;
  sleep 5 ;
fi
sync
