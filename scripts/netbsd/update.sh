#!/bin/sh -eux

set +e
## netbsd/update.sh

. /root/distro_pkgs.txt
if [ -z "$(grep '^export JAVA_HOME' /etc/csh.cshrc)" ] ; then
  echo "export JAVA_HOME=${default_java_home}" >> /etc/csh.cshrc ; 
fi
if [ -z "$(grep '^fdesc' /etc/fstab)" ] ; then
  echo 'fdesc  /dev/fd  fdescfs  rw  0  0' >> /etc/fstab ; 
fi

pkgin update ; pkgin -y upgrade ; pkgin -y full-upgrade #pkg_add -u
pkgin -y install sudo #pkg_add sudo
pkgin -y clean # #?? clean
