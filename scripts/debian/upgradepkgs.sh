#!/bin/sh -eux

## scripts/upgradepkgs.sh
set +e

#arch="$(uname -r | sed 's|^.*[0-9]\{1,\}\.[0-9]\{1,\}\.[0-9]\{1,\}\(-[0-9]\{1,2\}\)-||')"
#sed -i '/main.*$/ s|main.*$|main contrib non-free|' /etc/apt/sources.list
#
#apt-get -y upgrade linux-image-${arch}
#apt-get -y --no-install-recommends install linux-headers-${arch} #linux-headers-$(uname -r)

apt-get -y update --allow-releaseinfo-change
apt-get -y upgrade ; apt-get -y dist-upgrade
apt-get -y --no-install-recommends install bsdmainutils file sudo openssl
#dpkg -l | grep "^hi"
apt-mark showhold ; sleep 3

apt-get -y clean

. /etc/os-release
#snapshot_name=${ID}_${VERSION}-$(date -u "+%Y%m%d")
snapshot_name=${ID}-${VERSION_ID}_${VERSION_CODENAME}-$(date -u "+%Y%m%d")

if command -v zpool > /dev/null ; then
  ZPOOLNM=${ZPOOLNM:-ospool0} ;

  zfs snapshot ${ZPOOLNM}/ROOT/default@${snapshot_name} ;
  # example remove: zfs destroy ospool0/ROOT/default@snap1

  zfs list -t snapshot ; sleep 5 ;
  zpool trim ${ZPOOLNM} ; zpool set autotrim=on ${ZPOOLNM} ;
else
  if command -v btrfs > /dev/null ; then
    btrfs subvolume snapshot / /.snapshots/${snapshot_name} ;
    # example remove: btrfs subvolume delete /.snapshots/snap1

    btrfs subvolume list / ; sleep 5 ;
  elif command -v lvcreate > /dev/null ; then
    GRP_NM=${GRP_NM:-vg0} ;

    lvcreate --snapshot --size 2G --name ${snapshot_name} ${GRP_NM}/osRoot ;
    # example remove: lvremove vg0/snap1

    lvs ; sleep 5 ;
  fi ;
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
