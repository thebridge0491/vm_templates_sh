#!/bin/sh -x

# nc -l [-p] {port} > file ## nc -w3 {host} {port} < file  # netcat xfr
# ssh user@ipaddr "su -c 'sh -xs - arg1 argN'" < script.sh
# ssh user@ipaddr "sudo sh -xs - arg1 argN" < script.sh  # w/ sudo

set -x
DEVX=${DEVX:-sda}

#vgremove -v vg0 ; pvremove -v /dev/${DEVX}3  # for leftover LVM vols

parttbl_bkup() {
  TOOL=${1:-sgdisk}
  
  echo "Backing up partition table" ; sleep 3
  case $TOOL in
    'sfdisk') sfdisk --dump /dev/${DEVX} > parttbl_${DEVX}.dump ;
      echo "to restore: sfdisk /dev/${DEVX} < parttbl_${DEVX}.dump" ;;
    *) sgdisk --backup parttbl_${DEVX}.bak /dev/${DEVX} ;
      echo "to restore: sgdisk --load-backup parttbl_${DEVX}.bak /dev/${DEVX}" ;;
  esac
}

_sgdisk_hdpartlvm() {
  PV_NM0=${1:-pvol0} ; PV_NM1=${2:-pvol1}
  
  #sgdisk --zap --clear --mbrtogpt /dev/${DEVX} ; sync
  # typecode: for BIOS 1M fat|ef02 (bios_boot) ; for EFI 20M efi|ef00 (ESP)
  sgdisk --new 1:1M:+1M --typecode 1:ef02 --change-name 1:"bios_boot" \
    /dev/${DEVX}
  sgdisk --new 2:0:+200M --typecode 2:ef00 --change-name 2:"ESP" /dev/${DEVX}
  
  sgdisk --new 3:0:+84G --typecode 3:8e00 --change-name 3:"${PV_NM0}" \
    /dev/${DEVX}
  sgdisk --new 4:0:+80G --typecode 4:8e00 --change-name 4:"${PV_NM1}" \
    /dev/${DEVX}
  
  sgdisk --new 5:0:+4G --typecode 5:a502 --change-name 5:"fsSwap" /dev/${DEVX}
  sgdisk --new 6:0:+80G --typecode 6:a503 --change-name 6:"zvol0" /dev/${DEVX}
  
  sgdisk --new 7:0:+120G --typecode 7:0700 --change-name 7:"data0" \
    /dev/${DEVX}
  sgdisk --new 8:0:+80G --typecode 8:0700 --change-name 8:"data1" \
    /dev/${DEVX} # --new 8:0:+0G
  
  sync ; sgdisk --print /dev/${DEVX} ; sgdisk --verify /dev/${DEVX}
  sleep 3 ; partprobe --summary
  #DEV_ESP=$(blkid | grep -e ESP | cut -d: -f1)
  DEV_ESP=$(lsblk -nlpo name,partlabel | grep -e ESP | cut -d' ' -f1)
  sleep 3 ; yes | mkfs.fat -n ESP -F 32 ${DEV_ESP} ; sleep 3
}
_sfdisk_hdpartlvm() {
  PV_NM0=${1:-pvol0} ; PV_NM1=${2:-pvol1}
  
  #sfdisk --delete --wipe always /dev/${DEVX} ; sync
  echo -n 'label: gpt' | sfdisk /dev/${DEVX}
  # [s]fdisk type(s) (fdisk /dev/sdX; l):
  # shortcut | MBR | GPT
  #          |  4  | 21686148-6449-6E6F-744E-656564454649 (BIOS boot)
  #  U(EFI)  | EF  | C12A7328-F81F-11D2-BA4B-00A0C93EC93B
  #  L(inux) default | 83 | 0FC63DAF-8483-4772-8E79-3D69D8477DE4
  echo -n start=1MiB,size=1MiB,bootable,type=21686148-6449-6E6F-744E-656564454649,name=bios_boot | sfdisk -N 1 /dev/${DEVX}
  echo -n size=200MiB,bootable,type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B,name=ESP | sfdisk -N 2 \
    /dev/${DEVX}
  
  echo -n size=84GiB,name=${PV_NM0} | sfdisk -N 3 /dev/${DEVX}
  echo -n size=80GiB,name=${PV_NM1} | sfdisk -N 4 /dev/${DEVX}
  
  echo -n size=4GiB,type=516E7CB5-6ECF-11D6-8FF8-00022D09712B,name=fsSwap | sfdisk -N 5 /dev/${DEVX}
  echo -n size=80GiB,type=516E7CB6-6ECF-11D6-8FF8-00022D09712B,name=zvol0 | sfdisk -N 6 /dev/${DEVX}
  
  echo -n size=120GiB,type=EBD0A0A2-B9E5-4433-87C0-68B6B72699C7,name=data0 | sfdisk -N 7 /dev/${DEVX}
  #echo -n type=EBD0A0A2-B9E5-4433-87C0-68B6B72699C7,name=data1 | sfdisk -N 8 /dev/${DEVX}
  echo -n size=80GiB,type=EBD0A0A2-B9E5-4433-87C0-68B6B72699C7,name=data1 | sfdisk -N 8 /dev/${DEVX}
  
  sync ; sfdisk --list /dev/${DEVX} ; sleep 3 ; sfdisk --verify /dev/${DEVX}
  sleep 3 ; partprobe --summary
  DEV_ESP=$(lsblk -nlpo name,partlabel | grep -e ESP | cut -d' ' -f1)
  sleep 3 ; yes | mkfs.fat -n ESP -F 32 ${DEV_ESP} ; sleep 3
}
_parted_hdpartlvm() {
  PV_NM0=${1:-pvol0} ; PV_NM1=${2:-pvol1}
  
  parted --script /dev/${DEVX} mklabel gpt
  DIFF=1 ; END='-0'
  # /dev/${DEVX}: for BIOS 1M none (bios_boot) ; for EFI 200M fat32 (ESP)
  parted -s -a optimal /dev/${DEVX} unit MiB \
    mkpart primary $DIFF $END name 1 bios_boot
  DIFF=$END ; END=$(( 200 + $DIFF ))
  parted -s -a optimal /dev/${DEVX} unit MiB \
    mkpart primary fat32 $DIFF $END name 2 ESP
  
  DIFF=$END ; END=$(( 84 * 1024 + $DIFF ))
  parted -s -a optimal /dev/${DEVX} unit MiB \
    mkpart primary ext2 $DIFF $END name 3 ${PV_NM0}
  DIFF=$END ; END=$(( 80 * 1024 + $DIFF ))
  parted -s -a optimal /dev/${DEVX} unit MiB \
    mkpart primary ext2 $DIFF $END name 4 ${PV_NM1}
  
  DIFF=$END ; END=$(( 4 * 1024 + $DIFF ))
  parted -s -a optimal /dev/${DEVX} unit MiB \
    mkpart primary $DIFF $END name 5 fsSwap
  DIFF=$END ; END=$(( 80 * 1024 + $DIFF ))
  parted -s -a optimal /dev/${DEVX} unit MiB \
    mkpart primary $DIFF $END name 6 zvol0
  
  DIFF=$END ; END=$(( 120 * 1024 + $DIFF ))
  parted -s -a optimal /dev/${DEVX} unit MiB \
    mkpart primary ntfs $DIFF $END name 7 data0
  DIFF=$END ; END=$(( 80 * 1024 + $DIFF )) #; END=100%
  parted -s -a optimal /dev/${DEVX} unit MiB \
    mkpart primary ntfs $DIFF $END name 8 data1
  
  parted -s /dev/${DEVX} set 1 bios_grub on
  parted -s /dev/${DEVX} set 2 esp on
  
  sync ; parted -s /dev/${DEVX} unit GiB print ; sleep 3
  parted -s /dev/${DEVX} align-check optimal 1 ; sleep 3
  sleep 3 ; partprobe --summary
  DEV_ESP=$(lsblk -nlpo name,partlabel | grep -e ESP | cut -d' ' -f1)
  sleep 3 ; yes | mkfs.fat -n ESP -F 32 ${DEV_ESP} ; sleep 3
}


_sgdisk_hdpartstd() {
  GRP_NM0=${1:-vg0} ; GRP_NM1=${2:-vg1}
  
  #sgdisk --zap --clear --mbrtogpt /dev/${DEVX} ; sync
  # typecode: for BIOS 1M fat|ef02 (bios_boot) ; for EFI 20M efi|ef00 (ESP)
  sgdisk --new 1:1M:+1M --typecode 1:ef02 --change-name 1:"bios_boot" \
    /dev/${DEVX}
  sgdisk --new 2:0:+200M --typecode 2:ef00 --change-name 2:"ESP" /dev/${DEVX}
  
  sgdisk --new 3:0:+4G --typecode 3:8200 --change-name 3:"${GRP_NM0}-osSwap" /dev/${DEVX}
  sgdisk --new 4:0:+16G --typecode 4:8300 --change-name 4:"${GRP_NM0}-osRoot" /dev/${DEVX}
  sgdisk --new 5:0:+8G --typecode 5:8300 --change-name 5:"${GRP_NM0}-osVar" /dev/${DEVX}
  sgdisk --new 6:0:+32G --typecode 6:8300 --change-name 6:"${GRP_NM0}-osHome" /dev/${DEVX}
  sgdisk --new 7:0:+24G --typecode 7:8300 --change-name 7:"${GRP_NM0}-osFree" /dev/${DEVX}
  
  sgdisk --new 8:0:+16G --typecode 8:8300 --change-name 8:"${GRP_NM1}-osRoot" /dev/${DEVX}
  sgdisk --new 9:0:+8G --typecode 9:8300 --change-name 9:"${GRP_NM1}-osVar" /dev/${DEVX}
  sgdisk --new 10:0:+32G --typecode 10:8300 --change-name 10:"${GRP_NM1}-osHome" /dev/${DEVX}
  sgdisk --new 11:0:+24G --typecode 11:8300 --change-name 11:"${GRP_NM1}-osFree" /dev/${DEVX}
  
  sgdisk --new 12:0:+4G --typecode 12:a502 --change-name 12:"fsSwap" /dev/${DEVX}
  sgdisk --new 13:0:+16G --typecode 13:a503 --change-name 13:"zvol0" /dev/${DEVX}
  
  sgdisk --new 14:0:+120G --typecode 14:0700 --change-name 14:"data0" \
    /dev/${DEVX}
  sgdisk --new 15:0:+80G --typecode 15:0700 --change-name 15:"data1" \
    /dev/${DEVX} # --new 15:0:+0G
  
  sync ; sgdisk --print /dev/${DEVX} ; sgdisk --verify /dev/${DEVX}
  sleep 3 ; partprobe --summary
  DEV_ESP=$(lsblk -nlpo name,partlabel | grep -e ESP | cut -d' ' -f1)
  sleep 3 ; yes | mkfs.fat -n ESP -F 32 ${DEV_ESP} ; sleep 3
}
_sfdisk_hdpartstd() {
  GRP_NM0=${1:-vg0} ; GRP_NM1=${2:-vg1}
  
  #sfdisk --delete --wipe always /dev/${DEVX} ; sync
  echo -n 'label: gpt' | sfdisk /dev/${DEVX}
  # [s]fdisk type(s) (fdisk /dev/sdX; l):
  # shortcut | MBR | GPT
  #          |  4  | 21686148-6449-6E6F-744E-656564454649 (BIOS boot)
  #  U(EFI)  | EF  | C12A7328-F81F-11D2-BA4B-00A0C93EC93B
  #  Linux swap | 82 | 0657FD6D-A4AB-43C4-84E5-0933C84B4F4F
  #  L(inux) default | 83 | 0FC63DAF-8483-4772-8E79-3D69D8477DE4
  echo -n start=1MiB,size=1MiB,bootable,type=21686148-6449-6E6F-744E-656564454649,name=bios_boot | sfdisk -N 1 --label gpt /dev/${DEVX}
  echo -n size=200MiB,bootable,type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B,name=ESP | sfdisk -N 2 \
    /dev/${DEVX}
  
  echo -n size=4GiB,type=0657FD6D-A4AB-43C4-84E5-0933C84B4F4F,name="${GRP_NM0}-osSwap" | sfdisk -N 3 /dev/${DEVX}
  echo -n size=16GiB,name="${GRP_NM0}-osRoot" | sfdisk -N 4 /dev/${DEVX}
  echo -n size=8GiB,name="${GRP_NM0}-osVar" | sfdisk -N 5 /dev/${DEVX}
  echo -n size=32GiB,name="${GRP_NM0}-osHome" | sfdisk -N 6 /dev/${DEVX}
  echo -n size=24GiB,name="${GRP_NM0}-osFree" | sfdisk -N 7 /dev/${DEVX}
  
  echo -n size=16GiB,name="${GRP_NM1}-osRoot" | sfdisk -N 8 /dev/${DEVX}
  echo -n size=8GiB,name="${GRP_NM1}-osVar" | sfdisk -N 9 /dev/${DEVX}
  echo -n size=32GiB,name="${GRP_NM1}-osHome" | sfdisk -N 10 /dev/${DEVX}
  echo -n size=24GiB,name="${GRP_NM1}-osFree" | sfdisk -N 11 /dev/${DEVX}
  
  echo -n size=4GiB,type=516E7CB5-6ECF-11D6-8FF8-00022D09712B,name=fsSwap | sfdisk -N 12 /dev/${DEVX}
  echo -n size=16GiB,type=516E7CB6-6ECF-11D6-8FF8-00022D09712B,name=zvol0 | sfdisk -N 13 /dev/${DEVX}
  
  echo -n size=120GiB,type=EBD0A0A2-B9E5-4433-87C0-68B6B72699C7,name=data0 | sfdisk -N 14 /dev/${DEVX}
  #echo -n type=EBD0A0A2-B9E5-4433-87C0-68B6B72699C7,name=data1 | sfdisk -N 15 /dev/${DEVX}
  echo -n size=80GiB,type=EBD0A0A2-B9E5-4433-87C0-68B6B72699C7,name=data1 | sfdisk -N 15 /dev/${DEVX}
  
  sync ; sfdisk --list /dev/${DEVX} ; sleep 3 ; sfdisk --verify /dev/${DEVX}
  sleep 3 ; partprobe --summary
  DEV_ESP=$(lsblk -nlpo name,partlabel | grep -e ESP | cut -d' ' -f1)
  sleep 3 ; yes | mkfs.fat -n ESP -F 32 ${DEV_ESP} ; sleep 3
}
_parted_hdpartstd() {
  GRP_NM0=${1:-vg0} ; GRP_NM1=${2:-vg1}
  
  parted --script /dev/${DEVX} mklabel gpt
  DIFF=1 ; END='-0'
  # /dev/${DEVX}: for BIOS 1M none (bios_boot) ; for EFI 200M fat32 (ESP)
  END=$(( 1 + $DIFF ))
  parted -s -a optimal /dev/${DEVX} unit MiB \
    mkpart primary $DIFF $END name 1 bios_boot
  DIFF=$END ; END=$(( 200 + $DIFF ))
  parted -s -a optimal /dev/${DEVX} unit MiB \
    mkpart primary fat32 $DIFF $END name 2 ESP
  
  DIFF=$END ; END=$(( 4 * 1024 + $DIFF ))
  parted -s -a optimal /dev/${DEVX} unit MiB \
    mkpart primary ext2 $DIFF $END name 3 ${GRP_NM0}-osSwap
  DIFF=$END ; END=$(( 16 * 1024 + $DIFF ))
  parted -s -a optimal /dev/${DEVX} unit MiB \
    mkpart primary ext2 $DIFF $END name 4 ${GRP_NM0}-osRoot
  DIFF=$END ; END=$(( 8 * 1024 + $DIFF ))
  parted -s -a optimal /dev/${DEVX} unit MiB \
    mkpart primary ext2 $DIFF $END name 5 ${GRP_NM0}-osVar
  DIFF=$END ; END=$(( 32 * 1024 + $DIFF ))
  parted -s -a optimal /dev/${DEVX} unit MiB \
    mkpart primary ext2 $DIFF $END name 6 ${GRP_NM0}-osHome
  DIFF=$END ; END=$(( 24 * 1024 + $DIFF ))
  parted -s -a optimal /dev/${DEVX} unit MiB \
    mkpart primary ext2 $DIFF $END name 7 ${GRP_NM0}-osFree

  DIFF=$END ; END=$(( 16 * 1024 + $DIFF ))
  parted -s -a optimal /dev/${DEVX} unit MiB \
    mkpart primary ext2 $DIFF $END name 8 ${GRP_NM1}-osRoot
  DIFF=$END ; END=$(( 8 * 1024 + $DIFF ))
  parted -s -a optimal /dev/${DEVX} unit MiB \
    mkpart primary ext2 $DIFF $END name 9 ${GRP_NM1}-osVar
  DIFF=$END ; END=$(( 32 * 1024 + $DIFF ))
  parted -s -a optimal /dev/${DEVX} unit MiB \
    mkpart primary ext2 $DIFF $END name 10 ${GRP_NM1}-osHome
  DIFF=$END ; END=$(( 24 * 1024 + $DIFF ))
  parted -s -a optimal /dev/${DEVX} unit MiB \
    mkpart primary ext2 $DIFF $END name 11 ${GRP_NM1}-osFree
  
  DIFF=$END ; END=$(( 4 * 1024 + $DIFF ))
  parted -s -a optimal /dev/${DEVX} unit MiB \
    mkpart primary $DIFF $END name 12 fsSwap
  DIFF=$END ; END=$(( 16 * 1024 + $DIFF ))
  parted -s -a optimal /dev/${DEVX} unit MiB \
    mkpart primary $DIFF $END name 13 zvol0
  
  DIFF=$END ; END=$(( 120 * 1024 + $DIFF ))
  parted -s -a optimal /dev/${DEVX} unit MiB \
    mkpart primary ntfs $DIFF $END name 14 data0
  DIFF=$END ; END=$(( 80 * 1024 + $DIFF )) #; END=100%
  parted -s -a optimal /dev/${DEVX} unit MiB \
    mkpart primary ntfs $DIFF $END name 15 data1
  
  parted -s /dev/${DEVX} set 1 bios_grub on
  parted -s /dev/${DEVX} set 2 esp on
  
  sync ; parted -s /dev/${DEVX} unit GiB print ; sleep 3
  parted -s /dev/${DEVX} align-check optimal 1 ; sleep 3
  sleep 3 ; partprobe --summary
  DEV_ESP=$(lsblk -nlpo name,partlabel | grep -e ESP | cut -d' ' -f1)
  sleep 3 ; yes | mkfs.fat -n ESP -F 32 ${DEV_ESP} ; sleep 3
}


part_hddisk() {
  TOOL=${1:-sgdisk} ; VOL_TYPE=${2:-lvm} ; GRP_NM0=${3:-vg0}
  GRP_NM1=${4:-vg1} ; PV_NM0=${5:-pvol0} ; PV_NM1=${6:-pvol1}
  
  echo "Partitioning disk" ; sleep 3
  if [ "${VOL_TYPE}" = "lvm" ] ; then
    case $TOOL in
      'sfdisk') _sfdisk_hdpartlvm ${PV_NM0} ${PV_NM1} ;;
      'parted') _parted_hdpartlvm ${PV_NM0} ${PV_NM1} ;;
      *) _sgdisk_hdpartlvm ${PV_NM0} ${PV_NM1} ;;
    esac ;
  else
    case $TOOL in
      'sfdisk') _sfdisk_hdpartstd $GRP_NM0 $GRP_NM1 ;;
      'parted') _parted_hdpartstd $GRP_NM0 $GRP_NM1 ;;
      *) _sgdisk_hdpartstd $GRP_NM0 $GRP_NM1 ;;
    esac ;
  fi
}

lvmpv_create() {
  PARTS_NM_SZ=${PARTS_NM_SZ:-osSwap:4G osRoot:16G osVar:8G osHome:32G}
  GRP_NM=${1:-vg0} ; PV_NM=${2:-pvol0}
  
  #DEV_PV=$(blkid | grep -e ${PV_NM} | cut -d: -f1)
  DEV_PV=$(lsblk -nlpo name,partlabel | grep -e ${PV_NM} | cut -d' ' -f1)
  pvcreate ${DEV_PV} ; pvs ; sleep 3
  vgcreate ${GRP_NM} ${DEV_PV} ; vgs ; sleep 3
  for nm_sz in ${PARTS_NM_SZ} ; do
    lv_nm=$(echo $nm_sz | cut -d: -f1) ; lv_sz=$(echo $nm_sz | cut -d: -f2) ;
    lvcreate -n $lv_nm -L $lv_sz ${GRP_NM} ;
    if [ "osSwap" = "$lv_nm" ] ; then
      lvchange --contiguous y ${GRP_NM}/osSwap ;
    fi ;
  done
  vgscan ; vgchange -ay ; sleep 3 ; lvs ; sleep 3
}

format_partitions() {
  MKFS_CMD=${MKFS_CMD:-mkfs.ext4}
  PARTS_NM_SZ=${PARTS_NM_SZ:-osSwap:4G osRoot:16G osVar:8G osHome:32G}
  VOL_TYPE=${1:-lvm} ; GRP_NM=${2:-vg0} ; PV_NM=${3:-pvol0}
  
  echo "Formatting file systems" ; sleep 3
  if [ "${VOL_TYPE}" = "lvm" ] ; then
    lvmpv_create $GRP_NM $PV_NM ;
  fi
  for nm_sz in ${PARTS_NM_SZ} ; do
    lv_nm=$(echo $nm_sz | cut -d: -f1) ; lv_sz=$(echo $nm_sz | cut -d: -f2) ;
    #DEV_LV=$(blkid | grep -e "${GRP_NM}-${lv_nm}" | cut -d: -f1) ;
    DEV_LV=$(lsblk -nlpo name,label,partlabel | grep -e "${GRP_NM}-${lv_nm}" | cut -d' ' -f1) ;
    if [ "osSwap" = "$lv_nm" ] ; then
      yes | mkswap -L "${GRP_NM}-osSwap" ${DEV_LV} ;
    else
      yes | ${MKFS_CMD} -L "${GRP_NM}-${lv_nm}" ${DEV_LV} ;
    fi ;
  done
  sync
}

part_format_hddisk() {
  MKFS_CMD=${MKFS_CMD:-mkfs.ext4}
  PARTS_NM_SZ=${PARTS_NM_SZ:-osSwap:4G osRoot:16G osVar:8G osHome:32G}
  TOOL=${1:-sgdisk} ; VOL_TYPE=${2:-lvm} ; GRP_NM0=${3:-vg0}
  GRP_NM1=${4:-vg1} ; PV_NM0=${5:-pvol0} ; PV_NM1=${6:-pvol1}
  
  part_hddisk $TOOL $VOL_TYPE $GRP_NM0 $GRP_NM1 $PV_NM0 $PV_NM1
  format_partitions $VOL_TYPE $GRP_NM0 $PV_NM0
  PARTS_NM_SZ="osRoot:16G osVar:8G osHome:32G"
  format_partitions $VOL_TYPE $GRP_NM1 $PV_NM1
}

mount_filesystems() {
  GRP_NM=${1:-vg0}
  
  DEV_ROOT=$(lsblk -nlpo name,label,partlabel | grep -e "${GRP_NM}-osRoot" | cut -d' ' -f1)
  DEV_VAR=$(lsblk -nlpo name,label,partlabel | grep -e "${GRP_NM}-osVar" | cut -d' ' -f1)
  DEV_HOME=$(lsblk -nlpo name,label,partlabel | grep -e "${GRP_NM}-osHome" | cut -d' ' -f1)
  DEV_SWAP=$(lsblk -nlpo name,label,partlabel | grep -e "${GRP_NM}-osSwap" | cut -d' ' -f1)
  
  echo "Mounting file systems" ; sync ; sleep 3
  mkdir /mnt ; mount ${DEV_ROOT} /mnt
  mkdir -p /mnt/root /mnt/var /mnt/home
  mount ${DEV_VAR} /mnt/var ; mount ${DEV_HOME} /mnt/home
  swapon ${DEV_SWAP}

  #DEV_ESP=$(blkid | grep -e ESP | cut -d: -f1)
  DEV_ESP=$(lsblk -nlpo name,partlabel | grep -e ESP | cut -d' ' -f1)
  mkdir -p /mnt/boot/efi ; mount ${DEV_ESP} /mnt/boot/efi
  sync ; lsblk -l ; sleep 3
}

#----------------------------------------
$@
