#!/bin/sh -eux

set +e
## freebsd/update.sh

. /root/distro_pkgs.txt
if [ -z "$(grep '^setenv JAVA_HOME' /etc/csh.cshrc)" ] ; then
  echo "setenv JAVA_HOME ${default_java_home}" >> /etc/csh.cshrc ; 
fi
if [ -z "$(grep '^fdesc' /etc/fstab)" ] ; then
  echo 'fdesc  /dev/fd  fdescfs  rw  0  0' >> /etc/fstab ; 
fi


if command -v aria2c > /dev/null 2>&1 ; then
	FETCH_CMD=${FETCH_CMD:-aria2c} ;
fi
# Unset these as if they're empty it'll break freebsd-update
[ -z "$no_proxy" ] && unset no_proxy
[ -z "$http_proxy" ] && unset http_proxy
[ -z "$https_proxy" ] && unset https_proxy

major_version="$(uname -r | awk -F. '{print $1}')"

# Update FreeBSD
if [ "$major_version" -lt 10 ] ; then
  # Allow freebsd-update to run fetch without stdin attached to a terminal
  sed 's|\[ ! -t 0 \]|false|' freebsd-update > /tmp/freebsd-update ;
  chmod +x /tmp/freebsd-update ;

  freebsd_update="/tmp/freebsd-update" ;
else
  sed 's|sleep.*|sleep 30|' /usr/sbin/freebsd-update > /tmp/freebsd-update ;
  chmod +x /tmp/freebsd-update ;
  #freebsd_update="/usr/sbin/freebsd-update --not-running-from-cron" ;
  freebsd_update="/tmp/freebsd-update --not-running-from-cron" ;
fi

# NOTE: the install action fails if there are no updates so || true it
env PAGER=cat $freebsd_update cron      # interactive: fetch, else cron
env PAGER=cat $freebsd_update install || true


# Always use pkgng - pkg_add is EOL as of 1 September 2014
env ASSUME_ALWAYS_YES=true pkg bootstrap
if [ "$major_version" -lt 10 ] ; then
    #echo "WITH_PKGNG=yes" >> /etc/make.conf ;
    sed -i'' '/^WITH_PKGNG/ s|WITH_PKGNG=.*|WITH_PKGNG=yes|' /etc/make.conf ;
fi
pkg update ; pkg fetch -udy
pkg upgrade -y
pkg install -y sudo
pkg clean -y


portmaster -a
portmaster -n --clean-distfiles
sleep 3
