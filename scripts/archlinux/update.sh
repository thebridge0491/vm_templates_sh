#!/bin/sh -eux

## archlinux/update.sh
set +e

. /root/distro_pkgs.txt
if [ -z "$(grep '^export JAVA_HOME' /etc/bash.bashrc)" ] ; then
  echo "export JAVA_HOME=${default_java_home}" >> /etc/bash.bashrc ; 
fi
mkdir -p ${default_java_home}
if [ -z "$(grep '^JAVA_VERSION' ${default_java_home}/release)" ] ; then
  echo JAVA_VERSION="${default_java_version}" >> ${default_java_home}/release ; 
fi

systemctl stop pamac.service
rm /var/lib/pacman/db.lck
set -e
pacman --noconfirm -Syy ; pacman --noconfirm -Syu
pacman --noconfirm --needed -S base which sudo
pacman --noconfirm -Sc
set +e

MULTILIB_LINENO=$(grep -n "\[multilib\]" /etc/pacman.conf | cut -f1 -d:)
sed -i "${MULTILIB_LINENO}s|^#||" /etc/pacman.conf
MULTILIB_LINENO=$(( $MULTILIB_LINENO + 1 ))
sed -i "${MULTILIB_LINENO}s|^#||" /etc/pacman.conf
