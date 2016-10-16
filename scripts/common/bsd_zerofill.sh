#!/bin/sh -eux

PACKER_BUILDER_TYPE=${PACKER_BUILDER_TYPE:-qemu}
ZPARTNM=${ZPARTNM:-zvol0} ; ZPOOLNM=${ZPOOLNM:-zvRoot}

## common/zerofill.sh
case "$PACKER_BUILDER_TYPE" in
  virtualbox-iso|virtualbox-ovf) echo '' ;;
  *) exit 0 ;;
esac

if $(zfs list -H -o name ${ZPOOLNM}) ; then
  zfs set compression=off dedup=off ${ZPOOLNM} ;
fi

dd bs=4m if=/dev/zero of=/EMPTY || echo "dd exit code $? is suppressed"

if [ -z $(zfs list -H -o name ${ZPOOLNM}) ] ; then
  dd bs=4m if=/dev/zero of=/var/tmp/EMPTY || echo "dd exit code $? is suppressed" ;
  dd bs=4m if=/dev/zero of=/home/EMPTY || echo "dd exit code $? is suppressed" ;
  rm -f /home/EMPTY ; rm -f /var/tmp/EMPTY ;
fi

if $(zfs list -H -o name ${ZPOOLNM}) ; then
  zfs set compression=lz4 dedup=on ${ZPOOLNM} ;
  
  ## sysctl status: vfz.zfs.trim, kstat.zfs.misc.zio_trim
  #sysctl vfs.zfs.trim ; sleep 5 ;
  #sysctl kstat.zfs.misc.zio_trim ; sleep 5 ;
fi

rm -f /EMPTY
sync # Block until the empty file has been removed

swap_dev=$(swapctl -l | awk '!/^Device/ { print $1 }')
if [ -z "$swap_dev" ] ; then exit 0 ; fi
swapctl -d "$swap_dev"
dd bs=4m if=/dev/zero of="$swap_dev" || :

# manually trim(discard) unused UFS filesys blocks
#fsck_ffs -E -Z
