#!/bin/sh -eux

MIRROR=${MIRROR:-spout.ussg.indiana.edu}

os_version=$(grep VERSION= /etc/os-release | cut -f2 -d\" | cut -f1 -d\ )

## pclinuxos/update.sh
set +e

. /root/distro_pkgs.txt
if [ -z "$(grep '^export JAVA_HOME' /etc/bash.bashrc)" ] ; then
  echo "export JAVA_HOME=${default_java_home}" >> /etc/bash.bashrc ; 
fi
mkdir -p ${default_java_home}
if [ -z "$(grep '^JAVA_VERSION' ${default_java_home}/release)" ] ; then
  echo JAVA_VERSION="${default_java_version}" >> ${default_java_home}/release ; 
fi

grep -e '^rpm.*' /etc/apt/sources.list ; sleep 5
apt-get update
apt-get --fix-broken install -y
apt-get upgrade -y ; apt-get dist-upgrade -y
apt-get -y --option Retries=3 install sudo
apt-get clean -y
