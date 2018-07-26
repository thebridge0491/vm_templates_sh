#!/bin/sh -x

# nc -l [-p] {port} > file ## nc -w3 {host} {port} < file  # netcat xfr
# ssh user@ipaddr "sudo sh -xs - arg1 argN" < script.sh  # w/ sudo
# ssh user@ipaddr "su -m root -c 'sh -xs - arg1 argN'" < script.sh

set -x
DEVX=${DEVX:-sd0}

#zpool destroy zvRoot
#zpool labelclear ${DEVX}[x] # for leftover ZFS pools

parttbl_bkup() {
  echo "Backing up partition table" ; sleep 3
  gpt backup $DEVX > parttbl_${DEVX}.dump
  echo "to restore: gpt restore -l ${DEVX} < parttbl_${DEVX}.dump"
  echo "            gpt bootcode -b /boot/pmbr $DEVX"
}

gpt_vmdisk() {
  FSTYPE=${1:-ffs}
  
  echo "Partitioning disk" ; sleep 3
  gpt destroy $DEVX
  gpt create -f $DEVX
  gpt add -b 40 -a 1M -s 512K -t bios -l bsd1-gptboot0 $DEVX
  gpt add -a 1M -s 200M -t efi -l bsd1-efiboot $DEVX
  
  if [ "zfs" = "$FSTYPE" ] ; then
    gpt add -a 1M -s 1536M -t swap -l bsd1-fsSwap $DEVX ;
    gpt add -a 1M -t fbsd-zfs -l bsd1-zvol0 $DEVX ;
  
    #gpt biosboot -A -i 4 $DEVX
    gpt biosboot -L bsd1-zvol0 $DEVX
  else
    gpt add -a 1M -s 14G -t ffs -l bsd1-fsRoot $DEVX ;
    gpt add -a 1M -s 1536M -t swap -l bsd1-fsSwap $DEVX ;
    gpt add -a 1M -s 6G -t ffs -l bsd1-fsVar $DEVX ;
    gpt add -a 1M -t ffs -l bsd1-fsHome $DEVX ;
  
    #gpt biosboot -A -i 3 $DEVX
    gpt biosboot -L bsd1-fsRoot $DEVX
  fi
	
  #gpt set -a active -i 1 $DEVX ; gpt set -a bootme -i 1 $DEVX

  sync ; sleep 3
  #newfs_msdos -L ESP /dev/${DEVX}b
  newfs_msdos -F 16 -L ESP $(dkctl $DEVX listwedges | grep -e bsd1-efiboot | cut -d: -f1)
  #gpt label -l bsd1-efiboot -i 2 $DEVX ; gpt label -l bsd1-gptboot0 -i 1 $DEVX
  
  if [ "zfs" = "$FSTYPE" ] ; then
    PARTNM_LABELNMS="bsd1-gptboot0:bsd1-gptboot0 bsd1-efiboot:bsd1-efiboot bsd1-fsSwap:bsd1-fsSwap bsd1-zvol0:bsd1-zvol0" ;
    for partnm_labelnm in ${PARTNM_LABELNMS} ; do
      partnm=$(echo $partnm_labelnm | cut -d: -f1) ;
      labelnm=$(echo $partnm_labelnm | cut -d: -f2) ;
      idx=$(echo $(gpt show -l $DEVX | grep -e "$partnm") | cut -d' ' -f3) ;
      gpt label -l "$labelnm" -i $idx $DEVX ;
    done ;
  else
    PARTNM_LABELNMS="bsd1-gptboot0:bsd1-gptboot0 bsd1-efiboot:bsd1-efiboot bsd1-fsSwap:bsd1-fsSwap bsd1-fsRoot:bsd1-fsRoot bsd1-fsVar:bsd1-fsVar bsd1-fsHome:bsd1-fsHome" ;
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
  ZPARTNM_ZPOOLNMS=${1:-bsd1-zvol0:zvRoot}

  modload opensolaris ; modload zfs
  
  for zpartnm_zpoolnm in $ZPARTNM_ZPOOLNMS ; do
    zpartnm=$(echo $zpartnm_zpoolnm | cut -d: -f1) ;
    zpoolnm=$(echo $zpartnm_zpoolnm | cut -d: -f2) ;
    idx=$(echo $(gpt show -l $DEVX | grep -e "$zpartnm") | cut -d' ' -f3) ;
    dkZPart=$(dkctl $DEVX listwedges | grep -e "$zpartnm" | cut -d: -f1) ;
    
    zpool destroy $zpoolnm ;
    #zpool labelclear -f /dev/${DEVX}p${idx} ;
    zpool labelclear -f /dev/$dkZPart ;
    
    #zpool create -o altroot=/mnt -O atime=off -m none -f zvRoot ${DEVX}${idx} ;
    zpool create -R /mnt -O atime=off -m none -f zvRoot /dev/$dkZPart ;
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
  zpool list ; sleep 3 ; zfs list ; sleep 3
}

format_partitions() {
  MKFS_CMD=${MKFS_CMD:-newfs -O 2 -V 2 -f 2048}
  BSD_PARTNMS=${BSD_PARTNMS:-bsd1-fsSwap bsd1-fsRoot bsd1-fsVar bsd1-fsHome}
  
  FSTYPE=${1:-ffs} ; ZPARTNM_ZPOOLNMS=${2:-bsd1-zvol0:zvRoot}
  
  echo "Formatting file systems" ; sleep 3
  if [ "zfs" = "$FSTYPE" ] ; then
	zfspart_create $ZPARTNM_ZPOOLNMS ;
	
    for zpartnm_zpoolnm in $ZPARTNM_ZPOOLNMS ; do
      zpartnm=$(echo $zpartnm_zpoolnm | cut -d: -f1) ;
      zpoolnm=$(echo $zpartnm_zpoolnm | cut -d: -f2) ;
      idx=$(echo $(gpt show -l $DEVX | grep -e "$zpartnm") | cut -d' ' -f3) ;
      
      gpt label -l "$zpartnm" -i $idx $DEVX ;
    done ;
  else
    for partnm in ${BSD_PARTNMS} ; do
	  idx=$(echo $(gpt show -l $DEVX | grep -e "$partnm") | cut -d' ' -f3) ;
	  dkX=$(dkctl $DEVX listwedges | grep -e $partnm | cut -d: -f1) ;
      if [ ! "bsd1-fsSwap" = "$partnm" ] ; then
        ${MKFS_CMD} $dkX ;
        gpt label -l "$partnm" -i $idx $DEVX ;
      fi ;
      if [ "bsd1-fsRoot" = "$partnm" ] ; then
        mount -t cd9660 /dev/cd0 /mnt2 ;
        installboot -v -o timeout=15 /dev/$dkX /mnt2/usr/mdec/bootxx_ffsv2 ;
      fi ;
    done ;
  fi
  
  sync ; gpt show $DEVX ; sleep 3 ; gpt show -l $DEVX ; sleep 3
}

part_format_vmdisk() {
  FSTYPE=${1:-ffs} ; ZPARTNM_ZPOOLNMS=${2:-bsd1-zvol0:zvRoot}
  
  gpt_vmdisk $FSTYPE ; format_partitions $FSTYPE $ZPARTNM_ZPOOLNMS
}

mount_filesystems() {
  echo "Mounting file systems" ; sleep 3
  dkRoot=$(dkctl $DEVX listwedges | grep -e "bsd1-fsRoot" | cut -d: -f1)
  dkVar=$(dkctl $DEVX listwedges | grep -e "bsd1-fsVar" | cut -d: -f1)
  dkHome=$(dkctl $DEVX listwedges | grep -e "bsd1-fsHome" | cut -d: -f1)
  dkSwap=$(dkctl $DEVX listwedges | grep -e "bsd1-fsSwap" | cut -d: -f1)
  
  mount /dev/$dkRoot /mnt ; mkdir -p /mnt/var /mnt/usr/home
  mount /dev/$dkVar /mnt/var ; mount /dev/$dkHome /mnt/usr/home
  zfs mount -a
  swapon /dev/$dkSwap # OR: swapctl -a -p 1 $dkSwap
  
  cp /mnt2/usr/mdec/boot /mnt
  
  swapctl -l ; sleep 3 ; mount ; sleep 3 ; zfs mount ; sleep 3
}

#----------------------------------------
$@
