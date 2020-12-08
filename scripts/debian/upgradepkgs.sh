#!/bin/sh -eux

## scripts/upgradepkgs.sh
set +e

#arch="$(uname -r | sed 's|^.*[0-9]\{1,\}\.[0-9]\{1,\}\.[0-9]\{1,\}\(-[0-9]\{1,2\}\)-||')"
#sed -i '/main.*$/ s|main.*$|main contrib non-free|' /etc/apt/sources.list
#
#apt-get -y upgrade linux-image-$arch
#apt-get -y --no-install-recommends install linux-headers-$arch #linux-headers-$(uname -r)

apt-get -y update --allow-releaseinfo-change
apt-get -y upgrade ; apt-get -y dist-upgrade
apt-get -y --no-install-recommends install bsdmainutils file sudo openssl
#dpkg -l | grep "^hi"
apt-mark showhold ; sleep 3

apt-get -y clean
if command -v zpool > /dev/null ; then
  ZPOOLNM=${ZPOOLNM:-ospool0} ;
  zpool trim ${ZPOOLNM} ; zpool set autotrim=on ${ZPOOLNM} ;
else
  fstrim -av ;
fi
sync


#if [ -d /etc/init ] ; then
#    # update package index on boot
#    sh -c 'cat > /etc/init/refresh-apt.conf' << EOF ;
#description "update package index"
#start on networking
#task
#exec /usr/bin/apt-get update
#EOF
#fi
