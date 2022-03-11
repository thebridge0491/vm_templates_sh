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
if [ -e /dev/sd0 ] ; then
  export DEVX=sd0 ;
elif [ -e /dev/wd0 ] ; then
  export DEVX=wd0 ;
fi

#zpool destroy fspool0
#zpool labelclear ${DEVX}[x] # for leftover ZFS pools

parttbl_bkup() {
  echo "Backing up partition table" ; sleep 3
  gpt backup $DEVX > parttbl_${DEVX}.dump
  echo "to restore: gpt restore -l ${DEVX} < parttbl_${DEVX}.dump"
  echo "            gpt bootcode -b /boot/pmbr $DEVX"
}

gpt_disk() {
  VOL_MGR=${1:-std} ; GRP_NM=${2:-bsd1}

  echo "Partitioning disk" ; sleep 3
  gpt destroy $DEVX
  gpt create -f $DEVX
  gpt add -b 40 -a 1M -s 512K -t bios -l bios_boot $DEVX
  gpt add -a 1M -s 200M -t efi -l ESP $DEVX

  gpt add -a 1M -s 1G -t linux-data -l "vg0-osBoot" $DEVX
  gpt add -a 1M -s 4G -t linux-swap -l "vg0-osSwap" $DEVX
  gpt add -a 1M -s 80G -t linux-lvm -l "pvol0" $DEVX

  gpt add -a 1M -s 1G -t linux-data -l "vg1-osBoot" $DEVX
  gpt add -a 1M -s 80G -t linux-lvm -l "pvol1" $DEVX

  gpt add -a 1M -s 4G -t swap -l "${GRP_NM}-fsSwap" $DEVX

  if [ "zfs" = "$VOL_MGR" ] ; then
    gpt add -a 1M -s 80G -t fbsd-zfs -l "${GRP_NM}-fsPool" $DEVX ;

    #gpt biosboot -A -i 4 $DEVX
    gpt biosboot -L "${GRP_NM}-fsPool" $DEVX
  else
    gpt add -a 1M -s 20G -t ffs -l "${GRP_NM}-fsRoot" $DEVX ;
    gpt add -a 1M -s 8G -t ffs -l "${GRP_NM}-fsVar" $DEVX ;
    gpt add -a 1M -s 32G -t ffs -l "${GRP_NM}-fsHome" $DEVX ;
    gpt add -a 1M -s 20G -t ffs -l "${GRP_NM}-free" $DEVX ;

    #gpt biosboot -A -i 3 $DEVX
    gpt biosboot -L "${GRP_NM}-fsRoot" $DEVX
  fi

  gpt add -a 1M -s 120G -t ms-basic-data -l data0 $DEVX
  gpt add -a 1M -t ms-basic-data -l data1 $DEVX

  #gpt set -a active -i 1 $DEVX ; gpt set -a bootme -i 1 $DEVX

  sync ; sleep 3
  #newfs_msdos -L ESP /dev/${DEVX}b
  newfs_msdos -F 16 -L ESP $(dkctl $DEVX listwedges | grep -e ESP | cut -d: -f1)
  #gpt label -l ESP -i 2 $DEVX ; gpt label -l bios_boot -i 1 $DEVX

  if [ "zfs" = "$VOL_MGR" ] ; then
    PARTNM_LABELNMS="bios_boot:bios_boot ESP:ESP ${GRP_NM}-fsSwap:${GRP_NM}-fsSwap ${GRP_NM}-fsPool:${GRP_NM}-fsPool" ;
    for partnm_labelnm in ${PARTNM_LABELNMS} ; do
      partnm=$(echo $partnm_labelnm | cut -d: -f1) ;
      labelnm=$(echo $partnm_labelnm | cut -d: -f2) ;
      idx=$(echo $(gpt show -l $DEVX | grep -e "$partnm") | cut -d' ' -f3) ;
      gpt label -l "$labelnm" -i $idx $DEVX ;
    done ;
  else
    PARTNM_LABELNMS="bios_boot:bios_boot ESP:ESP ${GRP_NM}-fsSwap:${GRP_NM}-fsSwap ${GRP_NM}-fsRoot:${GRP_NM}-fsRoot ${GRP_NM}-fsVar:${GRP_NM}-fsVar ${GRP_NM}-fsHome:${GRP_NM}-fsHome" ;
    for partnm_labelnm in ${PARTNM_LABELNMS} ; do
      partnm=$(echo $partnm_labelnm | cut -d: -f1) ;
      labelnm=$(echo $partnm_labelnm | cut -d: -f2) ;
      idx=$(echo $(gpt show -l $DEVX | grep -e "$partnm") | cut -d' ' -f3) ;
      gpt label -l "$labelnm" -i $idx $DEVX ;
    done ;
  fi

  sync ; gpt show $DEVX ; sleep 3 ; gpt show -l $DEVX ; sleep 3
}

zfspart_create() {
  GRP_NM=${1:-bsd1} ; ZPARTNM_ZPOOLNM=${2:-${GRP_NM}-fsPool:fspool0}

  modload solaris ; modload zfs
  modstat -n zfs ; sleep 5

  zpartnm=$(echo $ZPARTNM_ZPOOLNM | cut -d: -f1)
  zpoolnm=$(echo $ZPARTNM_ZPOOLNM | cut -d: -f2)
  idx=$(echo $(gpt show -l $DEVX | grep -e "$zpartnm") | cut -d' ' -f3)
  dkZPart=$(dkctl $DEVX listwedges | grep -e "$zpartnm" | cut -d: -f1)

  zpool destroy $zpoolnm
  zpool labelclear -f /dev/$dkZPart

  zpool create -o altroot=/mnt -O compress=lz4 -O atime=off -m none \
	-O dedup=off -f $zpoolnm /dev/$dkZPart
  zfs create -o mountpoint=none $zpoolnm/ROOT
  zfs create -o canmount=noauto -o mountpoint=/ $zpoolnm/ROOT/default
  zfs mount $zpoolnm/ROOT/default

  zfs create -o exec=on -o setuid=off -o mountpoint=/tmp $zpoolnm/tmp
  zfs create -o canmount=off -o mountpoint=/usr $zpoolnm/usr
  zfs create -o mountpoint=/usr/home $zpoolnm/usr/home
  zfs create -o setuid=off $zpoolnm/usr/ports
  zfs create $zpoolnm/usr/src
  zfs create -o canmount=off -o mountpoint=/var $zpoolnm/var
  zfs create -o exec=off -o setuid=off $zpoolnm/var/audit
  zfs create -o exec=off -o setuid=off $zpoolnm/var/crash
  zfs create -o exec=off -o setuid=off $zpoolnm/var/log
  zfs create -o atime=on $zpoolnm/var/mail
  zfs create -o setuid=off $zpoolnm/var/tmp

  zfs set quota=32G $zpoolnm/usr/home
  zfs set quota=8G $zpoolnm/var
  zfs set quota=2G $zpoolnm/tmp

  zpool set bootfs=$zpoolnm/ROOT/default $zpoolnm # ??
  zpool set cachefile=/etc/zfs/zpool.cache $zpoolnm ; sync

  zpool export $zpoolnm ; sync ; sleep 3
  zpool import -R /mnt -N $zpoolnm
  zpool import -d /dev/$dkZPart -R /mnt -N $zpoolnm
  zfs mount $zpoolnm/ROOT/default ; zfs mount -a ; sync
  zpool set cachefile=/etc/zfs/zpool.cache $zpoolnm
  sync ; cat /etc/zfs/zpool.cache ; sleep 3
  mkdir -p /mnt/etc/zfs ; cp /etc/zfs/zpool.cache /mnt/etc/zfs/

  zpool list -v ; sleep 3 ; zfs list ; sleep 3
  zfs mount ; sleep 5
}

format_partitions() {
  VOL_MGR=${1:-std} ; GRP_NM=${2:-bsd1} ; ZPARTNM_ZPOOLNM=${3:-${GRP_NM}-fsPool:fspool0}
  MKFS_CMD=${MKFS_CMD:-newfs -O 2 -V 2 -f 2048}
  BSD_PARTNMS=${BSD_PARTNMS:-${GRP_NM}-fsSwap ${GRP_NM}-fsRoot ${GRP_NM}-fsVar ${GRP_NM}-fsHome}

  echo "Formatting file systems" ; sleep 3
  if [ "zfs" = "$VOL_MGR" ] ; then
	zfspart_create $GRP_NM $ZPARTNM_ZPOOLNM ;

    zpartnm=$(echo $ZPARTNM_ZPOOLNM | cut -d: -f1) ;
    zpoolnm=$(echo $ZPARTNM_ZPOOLNM | cut -d: -f2) ;
    idx=$(echo $(gpt show -l $DEVX | grep -e "$zpartnm") | cut -d' ' -f3) ;

    gpt label -l "$zpartnm" -i $idx $DEVX ;
  else
    modstat -n ffs ; sleep 5

    for partnm in ${BSD_PARTNMS} ; do
	  idx=$(echo $(gpt show -l $DEVX | grep -e "$partnm") | cut -d' ' -f3) ;
	  dkX=$(dkctl $DEVX listwedges | grep -e $partnm | cut -d: -f1) ;
      if [ ! "${GRP_NM}-fsSwap" = "$partnm" ] ; then
        ${MKFS_CMD} $dkX ;
        gpt label -l "$partnm" -i $idx $DEVX ;
      fi ;
      if [ "${GRP_NM}-fsRoot" = "$partnm" ] ; then
        mount -t cd9660 /dev/cd0 /mnt2 ;
        installboot -v -o timeout=15 /dev/$dkX /mnt2/usr/mdec/bootxx_ffsv2 ;
      fi ;
    done ;
  fi

  sync ; gpt show $DEVX ; sleep 3 ; gpt show -l $DEVX ; sleep 3
}

part_format() {
  VOL_MGR=${1:-std} ; GRP_NM=${2:-bsd1} ; ZPARTNM_ZPOOLNM=${3:-${GRP_NM}-fsPool:fspool0}

  gpt_disk $VOL_MGR $GRP_NM
  format_partitions $VOL_MGR $GRP_NM $ZPARTNM_ZPOOLNM
}

mount_filesystems() {
  VOL_MGR=${1:-std} ; GRP_NM=${2:-bsd1}
  echo "Mounting file systems" ; sleep 3
  if [ "zfs" = "$VOL_MGR" ] ; then
    zfs mount -a ;
  else
    dkRoot=$(dkctl $DEVX listwedges | grep -e "${GRP_NM}-fsRoot" | cut -d: -f1) ;
    dkVar=$(dkctl $DEVX listwedges | grep -e "${GRP_NM}-fsVar" | cut -d: -f1) ;
    dkHome=$(dkctl $DEVX listwedges | grep -e "${GRP_NM}-fsHome" | cut -d: -f1) ;

    mount /dev/$dkRoot /mnt ; mkdir -p /mnt/var /mnt/usr/home ;
    mount /dev/$dkVar /mnt/var ; mount /dev/$dkHome /mnt/usr/home ;
  fi
  dkSwap=$(dkctl $DEVX listwedges | grep -e "${GRP_NM}-fsSwap" | cut -d: -f1)
  swapon /dev/$dkSwap # OR: swapctl -a -p 1 $dkSwap

  cp /mnt2/usr/mdec/boot /mnt/
  cp /usr/mdec/boot /mnt/
}

#----------------------------------------
$@
