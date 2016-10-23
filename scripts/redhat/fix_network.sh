#!/bin/sh -eux

## redhat/networking.sh
major_version="$(sed 's|^.\+ release \([.0-9]\+\).*|\1|' /etc/redhat-release | awk -F. '{print $1}')"

if [ "$major_version" -ge 6 ] ; then
    # Fix slow DNS:
    # Add 'single-request-reopen': to include upon /etc/resolv.conf generation
    # https://access.redhat.com/site/solutions/58625 (subscription required)
    echo 'RES_OPTIONS="single-request-reopen"' >> /etc/sysconfig/network ;
    echo 'Slow DNS fix applied (single-request-reopen)' ;
fi

# Clean up network interface persistence
rm -rf /etc/udev/rules.d/70-persistent-net.rules
mkdir -p /etc/udev/rules.d/70-persistent-net.rules
rm -rf /lib/udev/rules.d/75-persistent-net-generator.rules
rm -rf /dev/.udev/

for ndev in $(ls -1 /etc/sysconfig/network-scripts/ifcfg-*) ; do
    if [ "$(basename $ndev)" != "ifcfg-lo" ] ; then
        sed -i '/^HWADDR/d' "$ndev" ;
        sed -i '/^UUID/d' "$ndev" ;
    fi
done
