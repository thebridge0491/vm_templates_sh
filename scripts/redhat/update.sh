#!/bin/sh -eux

## redhat/update.sh
set +e

. /root/distro_pkgs.txt
if [ -z "$(grep '^export JAVA_HOME' /etc/bash.bashrc)" ] ; then
  echo "export JAVA_HOME=${default_java_home}" >> /etc/bash.bashrc ; 
fi
mkdir -p ${default_java_home}
if [ -z "$(grep '^JAVA_VERSION' ${default_java_home}/release)" ] ; then
  echo JAVA_VERSION="${default_java_version}" >> ${default_java_home}/release ; 
fi

yum -y check-update ; yum -y upgrade
yum -y --setopt=requires_policy=strong --setopt=group_package_type=mandatory install @core yum-utils sudo openssl

distro="$(rpm -qf --queryformat '%{NAME}' /etc/redhat-release | cut -f 1 -d '-')" 
if [ "$distro" != 'redhat' ] ; then
  yum -y clean all ;
fi
