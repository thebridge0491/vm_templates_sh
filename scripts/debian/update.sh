#!/bin/sh -eux

## debian/update.sh
set +e

. /root/distro_pkgs.txt
if [ -z "$(grep '^export JAVA_HOME' /etc/bash.bashrc)" ] ; then
  echo "export JAVA_HOME=${default_java_home}" >> /etc/bash.bashrc ; 
fi
mkdir -p ${default_java_home}
if [ -z "$(grep '^JAVA_VERSION' ${default_java_home}/release)" ] ; then
  echo JAVA_VERSION="${default_java_version}" >> ${default_java_home}/release ; 
fi

apt-get update ; apt-get -y upgrade ; apt-get -y dist-upgrade
apt-get -y --no-install-recommends install bsdmainutils file sudo openssl
apt-get -y clean
