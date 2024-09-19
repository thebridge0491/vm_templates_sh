#!/bin/sh -x

# nc -l [-p] {port} > file ## nc -w3 {host} {port} < file  # netcat xfr
# ssh user@ipaddr "sudo sh -xs - arg1 argN" < script.sh  # w/ sudo
# ssh user@ipaddr "su -m root -c 'sh -xs - arg1 argN'" < script.sh

## WITHOUT availability of netcat or ssh/scp on system:
##  (host) simple http server for files:
##         php -S localhost:{port} [-t {dir}]
##         ruby -r un -e httpd -- [-b localhost] -p {port} {dir}
##         python -m http.server {port} [-b 0.0.0.0] [-d {dir}]
##  (host) kill HTTP server process: kill -9 $(pgrep -f 'python -m http\.server')
##  (client) tools:
##    [curl | wget | aria2c | fetch | ftp] http://{host}:{port}/{path}/file

set -x
if [ -n "`fdisk sd0`" ] ; then
  export DEVX=sd0 ;
elif [ -n "`fdisk wd0`" ] ; then
  export DEVX=wd0 ;
fi

parttbl_bkup() {
  echo "to backup partition table: disklabel -E ${DEVX}" ; sleep 3
  echo "            > s ${DEVX}.disklabel.bak" ; sleep 3
  echo "to restore: disklabel -R ${DEVX} ${DEVX}.disklabel.bak"
  disklabel -E ${DEVX}
}

disklabel_disk() {
  echo "Partitioning disk" ; sleep 3
  (cd /dev ; sh MAKEDEV ${DEVX})
  fdisk -iy -g -b 960 ${DEVX} ; sync
  echo 'make OpenBSD partition bootable: > print ; flag X ; write ; quit'
  sleep 5 ; fdisk -e ${DEVX}
  disklabel -w -A -T /tmp/custom.disklabel ${DEVX}

  sync ; newfs_msdos -L ESP ${DEVX}i

  fdisk ${DEVX} ; sleep 5 ; disklabel -h -p g -v ${DEVX} ; sleep 5
}

format_partitions() {
  MKFS_CMD=${MKFS_CMD:-newfs} ; BSD_PARTNMS=${BSD_PARTNMS:-b a d e f}

  echo "Formatting file systems" ; sleep 3
  for partnm in ${BSD_PARTNMS} ; do
    if [ ! "b" = "${partnm}" ] ; then
      ${MKFS_CMD} ${DEVX}${partnm} ;
    fi ;
    if [ "a" = "${partnm}" ] ; then
      installboot -v ${DEVX}a ; installboot -v /dev/r${DEVX}a ;
    fi ;
  done
  sync
}

part_format() {
  MKFS_CMD=${MKFS_CMD:-newfs} ; BSD_PARTNMS=${BSD_PARTNMS:-b a d e f}

  disklabel_disk ; format_partitions
}

mount_filesystems() {
  echo "Mounting file systems" ; sleep 3
  mount /dev/${DEVX}a /mnt ; mkdir -p /mnt/var /mnt/usr/local /mnt/home
  mount /dev/${DEVX}d /mnt/var ; mount /dev/${DEVX}e /mnt/usr/local
  mount /dev/${DEVX}f /mnt/home

  mkdir -p /mnt/etc /mnt/root
  sh -c 'cat > /mnt/etc/fstab' << EOF
/dev/${DEVX}a	/			ffs		rw					1	1
/dev/${DEVX}d	/var		ffs		rw,nodev,nosuid		1	2
/dev/${DEVX}e	/usr/local	ffs		rw,wxallowed,nodev	1	2
/dev/${DEVX}f	/home		ffs		rw,nodev,nosuid		1	2

/dev/${DEVX}b	none		swap	sw		0	0

swap			/tmp		mfs		rw,nodev,nosuid,-s=512m		0	0

#procfs             /proc       procfs  rw      0   0
#linprocfs          /compat/linux/proc  linprocfs   rw  0   0

EOF
  sed -i 's|rw|rw,noatime|' /mnt/etc/fstab

  swapon /dev/${DEVX}b #swapctl -p 1 /dev/${DEVX}b
  swapctl -l ; sleep 3 ; mount ; sleep 3
}

#----------------------------------------
${@}
