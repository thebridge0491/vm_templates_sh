#!/bin/sh -eux

if command -v aria2c > /dev/null 2>&1 ; then
	FETCH_CMD=${FETCH_CMD:-aria2c} ;
fi

# if never installed distribution ports.txz:
#portsnap cron ; portsnap extract        # interactive: fetch, else cron
portsnap cron update                    # interactive: fetch, else cron

cd /usr/ports/ports-mgmt/portmaster
make install

# compile/install exFAT support
pkgs_nms="autoconf autoconf-wrapper automake automake-wrapper fusefs-libs indexinfo libublio m4 pkgconf"
pkg fetch -dy $pkgs_nms ; pkg install -y $pkgs_nms

#cd /usr/ports/sysutils/exfat-utils ; make install  # install manually
portmaster sysutils/exfat-utils         # install using portmaster
portmaster -L ; sleep 5

# update ports
portmaster -a

# clean ports disk space usage
portmaster -y --clean-distfiles
