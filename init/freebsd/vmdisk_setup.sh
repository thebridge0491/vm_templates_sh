#!/bin/sh -x

# nc -l [-p] {port} > file ## nc -w3 {host} {port} < file  # netcat xfr
# ssh user@ipaddr "sudo sh -xs - arg1 argN" < script.sh  # w/ sudo
# ssh user@ipaddr "su -m root -c 'sh -xs - arg1 argN'" < script.sh

set -x
DEVX=${DEVX:-da0}

sysctl kern.geom.debugflags ; sysctl kern.geom.debugflags=16
sysctl kern.geom.label.disk_ident.enable=0
sysctl kern.geom.label.gptid.enable=0
sysctl kern.geom.label.gpt.enable=1

#zpool destroy zvRoot
#zpool labelclear ${DEVX}[x] # for leftover ZFS pools

parttbl_bkup() {
  echo "Backing up partition table" ; sleep 3
  gpart backup $DEVX > parttbl_${DEVX}.dump
  echo "to restore: gpart restore -l ${DEVX} < parttbl_${DEVX}.dump"
  echo "            gpart bootcode -b /boot/pmbr $DEVX"
}

gpart_vmdisk() {
  FSTYPE=${1:-ufs}
  
  echo "Partitioning disk" ; sleep 3
  #gpart destroy -F $DEVX
  gpart create -s gpt -f active $DEVX
  #gpart add -b 40 -a 1M -s 512K -t freebsd-boot -l gptboot0 $DEVX
  gpart add -b 1M -a 1M -s 512K -t freebsd-boot -l gptboot0 $DEVX
  gpart add -a 1M -s 200M -t efi -l efiboot $DEVX
  
  if [ "zfs" = "$FSTYPE" ] ; then
    gpart bootcode -b /boot/pmbr -p /boot/gptzfsboot -i 1 $DEVX ;
    
    gpart add -a 1M -s 1536M -t freebsd-swap -l fsSwap $DEVX ;
    gpart add -a 1M -t freebsd-zfs -l zvol0 $DEVX ;
  else
    gpart bootcode -b /boot/pmbr -p /boot/gptboot -i 1 $DEVX ;
    
    gpart add -a 1M -s 1536M -t freebsd-swap -l fsSwap $DEVX ;
    gpart add -a 1M -s 14G -t freebsd-ufs -l fsRoot $DEVX ;
    gpart add -a 1M -s 6G -t freebsd-ufs -l fsVar $DEVX ;
    gpart add -a 1M -t freebsd-ufs -l fsHome $DEVX ;
  fi
	
  gpart bootcode -b /boot/pmbr $DEVX
  #gpart set -a active -i 1 $DEVX ; gpart set -a bootme -i 1 $DEVX

  sync ; sleep 3 ; newfs_msdos -L ESP /dev/${DEVX}p2
  gpart modify -l gptboot0 -i 1 $DEVX ; gpart modify -l efiboot -i 2 $DEVX
  
  if [ "zfs" = "$FSTYPE" ] ; then
    PARTNM_LABELNMS="gptboot0:gptboot0 efiboot:efiboot fsSwap:fsSwap zvol0:zvol0" ;
    for partnm_labelnm in ${PARTNM_LABELNMS} ; do
      partnm=$(echo $partnm_labelnm | cut -d: -f1) ;
      labelnm=$(echo $partnm_labelnm | cut -d: -f2) ;
      idx=$(gpart show -l | grep -e "$partnm" | cut -w -f4) ;
      glabel label "$labelnm" /dev/${DEVX}p${idx} ;
    done ;
  else
    PARTNM_LABELNMS="gptboot0:gptboot0 efiboot:efiboot fsSwap:fsSwap fsRoot:fsRoot fsVar:fsVar fsHome:fsHome" ;
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
  ZPARTNM_ZPOOLNMS=${1:-zvol0:zvRoot}

  kldload opensolaris ; kldload zfs
  sysctl vfs.zfs.min_auto_ashift=12 ;
  
  for zpartnm_zpoolnm in $ZPARTNM_ZPOOLNMS ; do
    zpartnm=$(echo $zpartnm_zpoolnm | cut -d: -f1) ;
    zpoolnm=$(echo $zpartnm_zpoolnm | cut -d: -f2) ;
    idx=$(gpart show -l | grep -e "$zpartnm" | cut -w -f4) ;
    
    zpool destroy $zpoolnm ;
    zpool labelclear -f /dev/${DEVX}p${idx} ;
    
    zpool create -o altroot=/mnt -O compress=lz4 -O atime=off -m none \
		-f zvRoot ${DEVX}p${idx} ;
    zfs create -o mountpoint=none $zpoolnm/ROOT ;
    zfs create -o mountpoint=/ $zpoolnm/ROOT/default ;
    
    zfs create -o mountpoint=/tmp -o exec=on -o setuid=off $zpoolnm/tmp ;
    zfs create -o mountpoint=/usr -o canmount=off $zpoolnm/usr ;
    zfs create $zpoolnm/usr/home ;
    zfs create -o setuid=off $zpoolnm/usr/ports ;
    zfs create $zpoolnm/usr/src ;
    zfs create -o mountpoint=/var -o canmount=off $zpoolnm/var ;
    zfs create -o exec=off -o setuid=off $zpoolnm/var/audit ;
    zfs create -o exec=off -o setuid=off $zpoolnm/var/crash ;
    zfs create -o exec=off -o setuid=off $zpoolnm/var/log ;
    zfs create -o atime=on $zpoolnm/var/mail ;
    zfs create -o setuid=off $zpoolnm/var/tmp ;
    
    zfs set mountpoint=/$zpoolnm $zpoolnm ;
    zpool set bootfs=$zpoolnm/ROOT/default $zpoolnm ;
    mkdir -p /mnt/boot/zfs ;
    zpool set cachefile=/mnt/boot/zfs/zpool.cache $zpoolnm ;
    zfs set canmount=noauto $zpoolnm/ROOT/default ;
  done
  zpool list -v ; sleep 3 ; zfs list ; sleep 3
}

format_partitions() {
  MKFS_CMD=${MKFS_CMD:-newfs -U -t}
  BSD_PARTNMS=${BSD_PARTNMS:-fsSwap fsRoot fsVar fsHome}
  
  FSTYPE=${1:-ufs} ; ZPARTNM_ZPOOLNMS=${2:-zvol0:zvRoot}
  
  echo "Formatting file systems" ; sleep 3
  if [ "zfs" = "$FSTYPE" ] ; then
	zfspart_create $ZPARTNM_ZPOOLNMS ;
	
    for zpartnm_zpoolnm in $ZPARTNM_ZPOOLNMS ; do
      zpartnm=$(echo $zpartnm_zpoolnm | cut -d: -f1) ;
      zpoolnm=$(echo $zpartnm_zpoolnm | cut -d: -f2) ;
      idx=$(gpart show -l | grep -e "$zpartnm" | cut -w -f4) ;
      
      gpart modify -l $zpartnm -i $idx $DEVX ;
    done ;
  else
    for partnm in ${BSD_PARTNMS} ; do
	  idx=$(gpart show -l | grep -e "$partnm" | cut -w -f4) ;
      if [ ! "fsSwap" = "$partnm" ] ; then
        ${MKFS_CMD} -L $partnm /dev/gpt/$partnm ;
        gpart modify -l $partnm -i $idx $DEVX ;
      fi ;
    done ;
  fi
  
  sync ; gpart show -p ; sleep 3 ; gpart show -l ; sleep 3
}

part_format_vmdisk() {
  FSTYPE=${1:-ufs} ; ZPARTNM_ZPOOLNMS=${2:-zvol0:zvRoot}
  
  gpart_vmdisk $FSTYPE ; format_partitions $FSTYPE $ZPARTNM_ZPOOLNMS
}

mount_filesystems() {
  echo "Mounting file systems" ; sleep 3
  mount /dev/gpt/fsRoot /mnt ; mkdir -p /mnt/var /mnt/usr/home
  mount /dev/gpt/fsVar /mnt/var ; mount /dev/gpt/fsHome /mnt/usr/home
  zfs mount -a
  swapon /dev/gpt/fsSwap
}

#----------------------------------------
$@
