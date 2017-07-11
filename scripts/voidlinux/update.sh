#!/bin/sh -eux

## voidlinux/update.sh
set +e

. /root/distro_pkgs.txt
if [ -z "$(grep '^export JAVA_HOME' /etc/bash.bashrc)" ] ; then
  echo "export JAVA_HOME=${default_java_home}" >> /etc/bash.bashrc ; 
fi
mkdir -p ${default_java_home}
if [ -z "$(grep '^JAVA_VERSION' ${default_java_home}/release)" ] ; then
  echo JAVA_VERSION="${default_java_version}" >> ${default_java_home}/release ; 
fi

xbps-install -S ; xbps-install -y -u
xbps-install -y file sudo libressl
xbps-remove -O
