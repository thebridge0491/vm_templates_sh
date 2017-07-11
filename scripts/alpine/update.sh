#!/bin/sh -eux

## alpine/update.sh
set +e

. /root/distro_pkgs.txt
if [ -z "$(grep '^export JAVA_HOME' /etc/bash.bashrc)" ] ; then
  echo "export JAVA_HOME=${default_java_home}" >> /etc/bash.bashrc ; 
fi
mkdir -p ${default_java_home}
if [ -z "$(grep '^JAVA_VERSION' ${default_java_home}/release)" ] ; then
  echo JAVA_VERSION="${default_java_version}" >> ${default_java_home}/release ; 
fi

apk update ; apk upgrade -U -a
apk add file sudo openssl

mkdir -p /var/cache/apk ; ln -s /var/cache/apk /etc/apk/cache
apk -v cache clean
