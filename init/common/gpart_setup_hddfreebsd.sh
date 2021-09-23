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
if [ -e /dev/vtbd0 ] ; then
  export DEVX=vtbd0 ;
elif [ -e /dev/ada0 ] ; then
  export DEVX=ada0 ;
elif [ -e /dev/da0 ] ; then
  export DEVX=da0 ;
fi


sysctl kern.geom.debugflags ; sysctl kern.geom.debugflags=16
sysctl kern.geom.label.disk_ident.enable=0
sysctl kern.geom.label.gptid.enable=0
sysctl kern.geom.label.gpt.enable=1

#zpool destroy fspool0
#zpool labelclear ${DEVX}[x] # for leftover ZFS pools

parttbl_bkup() {
  echo "Backing up partition table" ; sleep 3
  gpart backup $DEVX > parttbl_${DEVX}.dump
  echo "to restore: gpart restore -l ${DEVX} < parttbl_${DEVX}.dump"
  echo "            gpart bootcode -b /boot/pmbr $DEVX"
}

gpart_hddisk() {
  VOL_MGR=${1:-zfs} ; GRP_NM=${2:-bsd0}

  echo "Partitioning disk" ; sleep 3
  #gpart destroy -F $DEVX
  gpart create -s gpt -f active $DEVX
  #gpart add -b 40 -a 1M -s 512K -t freebsd-boot -l bios_boot $DEVX
  gpart add -b 1M -a 1M -s 512K -t freebsd-boot -l bios_boot $DEVX
  gpart add -a 1M -s 200M -t efi -l ESP $DEVX

  gpart add -a 1M -s 1G -t linux-data -l "pvol0-osBoot" $DEVX
  gpart add -a 1M -s 84G -t linux-lvm -l "pvol0" $DEVX

  gpart add -a 1M -s 1G -t linux-data -l "pvol1-osBoot" $DEVX
  gpart add -a 1M -s 80G -t linux-lvm -l "pvol1" $DEVX

  if [ "zfs" = "$VOL_MGR" ] ; then
    gpart bootcode -b /boot/pmbr -p /boot/gptzfsboot -i 1 $DEVX ;

    gpart add -a 1M -s 4G -t freebsd-swap -l "${GRP_NM}-fsSwap" $DEVX ;
    gpart add -a 1M -s 80G -t freebsd-zfs -l "${GRP_NM}-fsPool" $DEVX ;
  else
    gpart bootcode -b /boot/pmbr -p /boot/gptboot -i 1 $DEVX ;

    gpart add -a 1M -s 4G -t freebsd-swap -l "${GRP_NM}-fsSwap" $DEVX ;
    gpart add -a 1M -s 16G -t freebsd-ufs -l "${GRP_NM}-fsRoot" $DEVX ;
    gpart add -a 1M -s 8G -t freebsd-ufs -l "${GRP_NM}-fsVar" $DEVX ;
    gpart add -a 1M -s 32G -t freebsd-ufs -l "${GRP_NM}-fsHome" $DEVX ;
    gpart add -a 1M -s 24G -t freebsd-ufs -l "${GRP_NM}-free" $DEVX ;
  fi

  gpart add -a 1M -s 120G -t ms-basic-data -l data0 $DEVX
  gpart add -a 1M -t ms-basic-data -l data1 $DEVX

  gpart bootcode -b /boot/pmbr $DEVX
  #gpart set -a active -i 1 $DEVX ; gpart set -a bootme -i 1 $DEVX

  sync ; sleep 3 ; newfs_msdos -L ESP /dev/${DEVX}p2
  gpart modify -l bios_boot -i 1 $DEVX ; gpart modify -l ESP -i 2 $DEVX

  if [ "zfs" = "$VOL_MGR" ] ; then
    PARTNM_LABELNMS="bios_boot:bios_boot ESP:ESP ${GRP_NM}-fsSwap:${GRP_NM}-fsSwap ${GRP_NM}-fsPool:${GRP_NM}-fsPool" ;
    for partnm_labelnm in ${PARTNM_LABELNMS} ; do
      partnm=$(echo $partnm_labelnm | cut -d: -f1) ;
      labelnm=$(echo $partnm_labelnm | cut -d: -f2) ;
      idx=$(gpart show -l | grep -e "$partnm" | cut -w -f4) ;
      glabel label "$labelnm" /dev/${DEVX}p${idx} ;
    done ;
  else
    PARTNM_LABELNMS="bios_boot:bios_boot ESP:ESP ${GRP_NM}-fsSwap:${GRP_NM}-fsSwap ${GRP_NM}-fsRoot:${GRP_NM}-fsRoot ${GRP_NM}-fsVar:${GRP_NM}-fsVar ${GRP_NM}-fsHome:${GRP_NM}-fsHome" ;
    for partnm_labelnm in ${PARTNM_LABELNMS} ; do
      partnm=$(echo $partnm_labelnm | cut -d: -f1) ;
      labelnm=$(echo $partnm_labelnm | cut -d: -f2) ;
      idx=$(gpart show -l | grep -e "$partnm" | cut -w -f4) ;
      glabel label "$labelnm" /dev/${DEVX}p${idx} ;
    done ;
  fi

  sync ; gpart show -p ; sleep 3 ; gpart show -l ; sleep 3
  glabel status ; sleep 3 ; geli status ; sleep 3
}

zfspart_create() {
  GRP_NM=${1:-bsd0} ; ZPARTNM_ZPOOLNM=${2:-${GRP_NM}-fsPool:fspool0}

  kldload opensolaris ; kldload zfs
  sysctl vfs.zfs.min_auto_ashift=12

  zpartnm=$(echo $ZPARTNM_ZPOOLNM | cut -d: -f1)
  zpoolnm=$(echo $ZPARTNM_ZPOOLNM | cut -d: -f2)
  idx=$(gpart show -l | grep -e "$zpartnm" | cut -w -f4)

  zpool destroy $zpoolnm
  zpool labelclear -f /dev/${DEVX}p${idx}

  zpool create -o altroot=/mnt -O compress=lz4 -O atime=off -m none \
	-O dedup=off -f $zpoolnm ${DEVX}p${idx}
  zfs create -o mountpoint=none $zpoolnm/ROOT
  zfs create -o canmount=noauto -o mountpoint=/ $zpoolnm/ROOT/default
  zfs mount $zpoolnm/ROOT/default

  zfs create -o mountpoint=/tmp -o exec=on -o setuid=off $zpoolnm/tmp
  zfs create -o mountpoint=/usr -o canmount=off $zpoolnm/usr
  zfs create $zpoolnm/usr/home
  zfs create -o setuid=off $zpoolnm/usr/ports
  zfs create $zpoolnm/usr/src
  zfs create -o mountpoint=/var -o canmount=off $zpoolnm/var
  zfs create -o exec=off -o setuid=off $zpoolnm/var/audit
  zfs create -o exec=off -o setuid=off $zpoolnm/var/crash
  zfs create -o exec=off -o setuid=off $zpoolnm/var/log
  zfs create -o atime=on $zpoolnm/var/mail
  zfs create -o setuid=off $zpoolnm/var/tmp

  zfs set quota=32G $zpoolnm/usr/home
  zfs set quota=8G $zpoolnm/var
  zfs set quota=2G $zpoolnm/tmp
  #zfs set mountpoint=/$zpoolnm $zpoolnm

  zpool set bootfs=$zpoolnm/ROOT/default $zpoolnm # ??
  zpool set cachefile=/etc/zfs/zpool.cache $zpoolnm ; sync

  zpool export $zpoolnm ; sync ; sleep 3
  zpool import -R /mnt -N $zpoolnm
  zpool import -d /dev/${DEVX}p${idx} -R /mnt -N $zpoolnm
  zfs mount $zpoolnm/ROOT/default ; zfs mount -a ; sync
  zpool set cachefile=/etc/zfs/zpool.cache $zpoolnm
  sync ; cat /etc/zfs/zpool.cache ; sleep 3
  mkdir -p /mnt/etc/zfs ; cp /etc/zfs/zpool.cache /mnt/etc/zfs/

  zpool list -v ; sleep 3 ; zfs list ; sleep 3
  zfs mount ; sleep 5
}

format_partitions() {
  VOL_MGR=${1:-zfs} ; GRP_NM=${2:-bsd0} ; ZPARTNM_ZPOOLNM=${3:-${GRP_NM}-fsPool:fspool0}
  MKFS_CMD=${MKFS_CMD:-newfs -U -t}
  BSD_PARTNMS=${BSD_PARTNMS:-${GRP_NM}-fsSwap ${GRP_NM}-fsRoot ${GRP_NM}-fsVar ${GRP_NM}-fsHome}

  echo "Formatting file systems" ; sleep 3
  if [ "zfs" = "$VOL_MGR" ] ; then
	zfspart_create $GRP_NM $ZPARTNM_ZPOOLNM ;

    zpartnm=$(echo $ZPARTNM_ZPOOLNM | cut -d: -f1) ;
    zpoolnm=$(echo $ZPARTNM_ZPOOLNM | cut -d: -f2) ;
    idx=$(gpart show -l | grep -e "$zpartnm" | cut -w -f4) ;

    gpart modify -l $zpartnm -i $idx $DEVX ;
  else
    for partnm in ${BSD_PARTNMS} ; do
	  idx=$(gpart show -l | grep -e "$partnm" | cut -w -f4) ;
      if [ ! "${GRP_NM}-fsSwap" = "$partnm" ] ; then
        ${MKFS_CMD} -L $partnm /dev/gpt/$partnm ;
        gpart modify -l $partnm -i $idx $DEVX ;
      fi ;
    done ;
  fi

  sync ; gpart show -p ; sleep 3 ; gpart show -l ; sleep 3
}

part_format_hddisk() {
  VOL_MGR=${1:-zfs} ; GRP_NM=${2:-bsd0} ; ZPARTNM_ZPOOLNM=${3:-${GRP_NM}-fsPool:fspool0}

  gpart_hddisk $VOL_MGR $GRP_NM
  format_partitions $VOL_MGR $GRP_NM $ZPARTNM_ZPOOLNM
}

mount_filesystems() {
  GRP_NM=${1:-bsd0}
  echo "Mounting file systems" ; sleep 3
  mount /dev/gpt/${GRP_NM}-fsRoot /mnt ; mkdir -p /mnt/var /mnt/usr/home
  mount /dev/gpt/${GRP_NM}-fsVar /mnt/var
  mount /dev/gpt/${GRP_NM}-fsHome /mnt/usr/home
  zfs mount -a
  swapon /dev/gpt/${GRP_NM}-fsSwap
}

#----------------------------------------
$@
