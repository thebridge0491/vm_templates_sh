#!/bin/sh -x

# nc -l [-p] {port} > file ## nc -w3 {host} {port} < file  # netcat xfr
# ssh user@ipaddr "sudo sh -xs - arg1 argN" < script.sh  # w/ sudo
# ssh user@ipaddr "su -m root -c 'sh -xs - arg1 argN'" < script.sh

## WITHOUT availability of netcat or ssh/scp on system:
##  (host) simple http server for files:
##         php -S localhost:{port} [-t {dir}]
##         ruby -run -e httpd -- -p {port} {dir}
##         python -m http.server {port} [-d {dir}]
##  (client) tools:
##    [curl | wget | aria2c | fetch | ftp] http://{host}:{port}/{path}/file

set -x
if [ -n "`fdisk sd0`" ] ; then
  export DEVX=sd0 ;
elif [ -n "`fdisk wd0`" ] ; then
  export DEVX=wd0 ;
fi

parttbl_bkup() {
  echo "to backup partition table: disklabel -E $DEVX" ; sleep 3
  echo "            > s ${DEVX}.disklabel.bak" ; sleep 3
  echo "to restore: disklabel -R $DEVX ${DEVX}.disklabel.bak"
  disklabel -E $DEVX
}

disklabel_vmdisk() {
  echo "Partitioning disk" ; sleep 3
  (cd /dev ; sh MAKEDEV $DEVX)
  fdisk -iy -g -b 960 $DEVX ; sync
  echo 'make OpenBSD partition bootable: > print ; flag X ; write ; quit'
  sleep 5 ; fdisk -e $DEVX
  disklabel -w -A -T /tmp/custom.disklabel $DEVX

  sync ; newfs_msdos -L ESP ${DEVX}i

  fdisk $DEVX ; sleep 5 ; disklabel -h -p g -v $DEVX ; sleep 5
}

format_partitions() {
  MKFS_CMD=${MKFS_CMD:-newfs} ; BSD_PARTNMS=${BSD_PARTNMS:-b a d e f}

  echo "Formatting file systems" ; sleep 3
  for partnm in ${BSD_PARTNMS} ; do
    if [ ! "b" = "$partnm" ] ; then
      ${MKFS_CMD} ${DEVX}$partnm ;
    fi ;
    if [ "a" = "$partnm" ] ; then
      installboot -v ${DEVX}a ; installboot -v /dev/r${DEVX}a ;
    fi ;
  done
  sync
}

part_format_vmdisk() {
  MKFS_CMD=${MKFS_CMD:-newfs} ; BSD_PARTNMS=${BSD_PARTNMS:-b a d e f}

  disklabel_vmdisk ; format_partitions
}

mount_filesystems() {
  echo "Mounting file systems" ; sleep 3
  mount /dev/${DEVX}a /mnt ; mkdir -p /mnt/var /mnt/usr/local /mnt/home
  mount /dev/${DEVX}d /mnt/var ; mount /dev/${DEVX}e /mnt/usr/local
  mount /dev/${DEVX}f /mnt/home
  swapon /dev/${DEVX}b #swapctl -p 1 /dev/${DEVX}b

  swapctl -l ; sleep 3 ; mount ; sleep 3
}

#----------------------------------------
$@
