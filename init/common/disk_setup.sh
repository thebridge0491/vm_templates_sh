#!/bin/sh -x

# nc -l [-p] {port} > file ## nc -w3 {host} {port} < file  # netcat xfr
# ssh user@ipaddr "su -c 'sh -xs - arg1 argN'" < script.sh
# ssh user@ipaddr "sudo sh -xs - arg1 argN" < script.sh  # w/ sudo

## WITHOUT availability of netcat or ssh/scp on system:
##  (host) simple http server for files:
##         php -S localhost:{port} [-t {dir}]
##         ruby -r un -e httpd -- [-b localhost] -p {port} {dir}
##         python -m http.server {port} [-b 0.0.0.0] [-d {dir}]
##  (host) kill HTTP server process: kill -9 $(pgrep -f 'python -m http\.server')
##  (client) tools:
##    [curl | wget | aria2c | fetch | ftp] http://{host}:{port}/{path}/file

set -x
if [ -e /dev/vda ] ; then
  export DEVX=vda ;
elif [ -e /dev/sda ] ; then
  export DEVX=sda ;
fi

#vgremove -v vg0 ; pvremove -v /dev/${DEVX}3  # for leftover LVM vols
#zpool destroy ospool0
#zpool labelclear ${DEVX}[x] # for leftover ZFS pools

parttbl_bkup() {
  TOOL=${1:-sgdisk}

  echo "Backing up partition table" ; sleep 3
  case ${TOOL} in
    'sfdisk') sfdisk --dump /dev/${DEVX} > parttbl_${DEVX}.dump ;
      echo "to restore: sfdisk /dev/${DEVX} < parttbl_${DEVX}.dump" ;;
    *) sgdisk --backup parttbl_${DEVX}.bak /dev/${DEVX} ;
      echo "to restore: sgdisk --load-backup parttbl_${DEVX}.bak /dev/${DEVX}" ;;
  esac
}

_sgdisk_part() {
  VOL_MGR=${1:-std} ; GRP_NM=${2:-vg0}

  sgdisk --zap --clear --mbrtogpt /dev/${DEVX} ; sync
  # typecode: f/ BIOS 1M fat|ef02 (bios_boot) ; f/ EFI 512M efi|ef00 (ESP)
  sgdisk --new 1:1M:+1M --typecode 1:ef02 --change-name 1:"bios_boot" \
    /dev/${DEVX}
  sgdisk --new 2:0:+512M --typecode 2:ef00 --change-name 2:"ESP" /dev/${DEVX}

  sgdisk --new 3:0:+1G --typecode 3:8300 --change-name 3:"${GRP_NM}-osBoot" /dev/${DEVX}
  sgdisk --new 4:0:+4G --typecode 4:8200 --change-name 4:"${GRP_NM}-osSwap" /dev/${DEVX}

  if [ "zfs" = "${VOL_MGR}" ] ; then
    sgdisk --new 5:0:-1M --typecode 5:BF00 --change-name 5:"${GRP_NM}-osPool" \
      /dev/${DEVX} ;
  elif [ "lvm" = "${VOL_MGR}" ] ; then
    sgdisk --new 5:0:-1M --typecode 5:8e00 --change-name 5:"${PV_NM}" \
      /dev/${DEVX} ;
  elif [ "btrfs" = "${VOL_MGR}" ] ; then
    sgdisk --new 5:0:-1M --typecode 5:8300 --change-name 5:"${PV_NM}" \
      /dev/${DEVX} ;
  elif [ "std" = "${VOL_MGR}" ] ; then
    sgdisk --new 5:0:+12G --typecode 5:8300 \
      --change-name 5:"${GRP_NM}-osRoot" /dev/${DEVX} ;
    sgdisk --new 6:0:+5G --typecode 6:8300 --change-name 6:"${GRP_NM}-osVar" \
      /dev/${DEVX} ;
    sgdisk --new 7:0:-1M --typecode 7:8300 --change-name 7:"${GRP_NM}-osHome" \
      /dev/${DEVX} ;
  fi

  sync ; sgdisk --print /dev/${DEVX} ; sgdisk --verify /dev/${DEVX}
  sleep 3 ; partprobe --summary || partprobe
}
_sfdisk_part() {
  VOL_MGR=${1:-std} ; GRP_NM=${2:-vg0}

  sfdisk --delete --wipe always /dev/${DEVX} ; sync
  echo -n 'label: gpt' | sfdisk /dev/${DEVX}
  # [s]fdisk type(s) (fdisk /dev/sdX; l):
  # shortcut | MBR | GPT
  #          |  4  | 21686148-6449-6E6F-744E-656564454649 (BIOS boot)
  #  U(EFI)  | EF  | C12A7328-F81F-11D2-BA4B-00A0C93EC93B
  #  Linux swap | 82 | 0657FD6D-A4AB-43C4-84E5-0933C84B4F4F
  #  L(inux) default | 83 | 0FC63DAF-8483-4772-8E79-3D69D8477DE4
  echo -n start=1MiB,size=1MiB,bootable,type=21686148-6449-6E6F-744E-656564454649,name=bios_boot | sfdisk -N 1 /dev/${DEVX}
  echo -n size=512MiB,bootable,type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B,name=ESP | sfdisk -N 2 \
    /dev/${DEVX}

  echo -n size=1GiB,type=516E7CB6-6ECF-11D6-8FF8-00022D09712B,name="${GRP_NM}-osBoot" | sfdisk -N 3 /dev/${DEVX}
  echo -n size=4GiB,type=0657FD6D-A4AB-43C4-84E5-0933C84B4F4F,name="${GRP_NM}-osSwap" | sfdisk -N 4 /dev/${DEVX}

  if [ "zfs" = "${VOL_MGR}" ] ; then
    echo -n type=516E7CB6-6ECF-11D6-8FF8-00022D09712B,name="${GRP_NM}-osPool" | \
      sfdisk -N 5 /dev/${DEVX} ;
  elif [ "lvm" = "${VOL_MGR}" ] || [ "btrfs" = "${VOL_MGR}" ] ; then
    echo -n name=${PV_NM} | sfdisk -N 5 /dev/${DEVX} ;
  elif [ "std" = "${VOL_MGR}" ] ; then
    echo -n size=12GiB,name="${GRP_NM}-osRoot" | sfdisk -N 5 /dev/${DEVX} ;
    echo -n size=5GiB,name="${GRP_NM}-osVar" | sfdisk -N 6 /dev/${DEVX} ;
    echo -n name="${GRP_NM}-osHome" | sfdisk -N 7 /dev/${DEVX} ;
  fi

  sync ; sfdisk --list /dev/${DEVX} ; sleep 3 ; sfdisk --verify /dev/${DEVX}
  sleep 3 ; partprobe --summary || partprobe
}
_parted_part() {
  VOL_MGR=${1:-std} ; GRP_NM=${2:-vg0}

  parted --script /dev/${DEVX} mklabel gpt
  DIFF=1 ; END='-0'
  # /dev/${DEVX}: f/ BIOS 1M none (bios_boot) ; f/ EFI 512M fat32 (ESP)
  END=$(( 1 + ${DIFF} ))
  parted -s -a optimal /dev/${DEVX} unit MiB \
    mkpart primary ${DIFF} ${END} name 1 bios_boot
  DIFF=${END} ; END=$(( 512 + ${DIFF} ))
  parted -s -a optimal /dev/${DEVX} unit MiB \
    mkpart primary fat32 ${DIFF} ${END} name 2 ESP

  DIFF=${END} ; END=$(( 1 * 1024 + ${DIFF} ))
  parted -s -a optimal /dev/${DEVX} unit MiB \
    mkpart primary ${DIFF} ${END} name 3 ${GRP_NM}-osBoot
  DIFF=${END} ; END=$(( 4 * 1024 + ${DIFF} ))
  parted -s -a optimal /dev/${DEVX} unit MiB \
    mkpart primary ext2 ${DIFF} ${END} name 4 ${GRP_NM}-osSwap

  if [ "zfs" = "${VOL_MGR}" ] ; then
    DIFF=${END} ; END=100% ;
    parted -s -a optimal /dev/${DEVX} unit MiB \
      mkpart primary ${DIFF} ${END} name 5 ${GRP_NM}-osPool ;
  elif [ "lvm" = "${VOL_MGR}" ] ; then
    DIFF=${END} ; END=100% ;
    parted -s -a optimal /dev/${DEVX} unit MiB \
      mkpart primary ext2 ${DIFF} ${END} name 5 ${PV_NM} ;
  elif [ "btrfs" = "${VOL_MGR}" ] ; then
    DIFF=${END} ; END=100% ;
    parted -s -a optimal /dev/${DEVX} unit MiB \
      mkpart primary btrfs ${DIFF} ${END} name 5 ${PV_NM} ;
  elif [ "std" = "${VOL_MGR}" ] ; then
    DIFF=${END} ; END=$(( 12 * 1024 + ${DIFF} )) ;
    parted -s -a optimal /dev/${DEVX} unit MiB \
      mkpart primary ext2 ${DIFF} ${END} name 5 ${GRP_NM}-osRoot ;
    DIFF=${END} ; END=$(( 5 * 1024 + ${DIFF} )) ;
    parted -s -a optimal /dev/${DEVX} unit MiB \
      mkpart primary ext2 ${DIFF} ${END} name 6 ${GRP_NM}-osVar ;
    DIFF=${END} ; END=100% ;
    parted -s -a optimal /dev/${DEVX} unit MiB \
      mkpart primary ext2 ${DIFF} ${END} name 7 ${GRP_NM}-osHome ;
  fi

  parted -s /dev/${DEVX} set 1 bios_grub on
  parted -s /dev/${DEVX} set 2 esp on

  sync ; parted -s /dev/${DEVX} unit GiB print ; sleep 3
  parted -s /dev/${DEVX} align-check optimal 1 ; sleep 3
  sleep 3 ; partprobe --summary || partprobe
}


part_disk() {
  TOOL=${1:-sgdisk} ; VOL_MGR=${2:-std} ; GRP_NM=${3:-vg0} ; PV_NM=${4:-pvol0}
  modprobe vfat ; lsmod | grep -e fat ; sleep 5

  echo "Partitioning disk" ; sleep 3
  case ${TOOL} in
    'sfdisk') _sfdisk_part ${VOL_MGR} ${GRP_NM} ${PV_NM} ;;
    'parted') _parted_part ${VOL_MGR} ${GRP_NM} ${PV_NM} ;;
    *) _sgdisk_part ${VOL_MGR} ${GRP_NM} ${PV_NM} ;;
  esac
}

zfspart_create() {
  ZPARTNM_ZPOOLNM=${1:-vg0-osPool:ospool0}
  modprobe zfs ; zfs version
  modinfo zfs | grep -e name -e version
  lsmod | grep -e zfs ; sleep 5

  zpartnm=$(echo ${ZPARTNM_ZPOOLNM} | cut -d: -f1)
  zpoolnm=$(echo ${ZPARTNM_ZPOOLNM} | cut -d: -f2)
  idx=$(lsblk -nlpo name,label,partlabel | sed -n "/${zpartnm}/ s|.*[sv]da\([0-9]*\).*|\1|p")

  zpool destroy ${zpoolnm} ;
  zpool labelclear -f /dev/${DEVX}${idx} ; mkdir -p /mnt

  #zpool create -R /mnt -O mountpoint=none -o ashift=12 -O compress=lz4 \
  zpool create -R /mnt -O mountpoint=/ -o ashift=12 -d \
    -o feature@async_destroy=enabled -o feature@bookmarks=enabled \
    -o feature@embedded_data=enabled -o feature@empty_bpobj=enabled \
    -o feature@enabled_txg=enabled -o feature@extensible_dataset=enabled \
    -o feature@filesystem_limits=enabled -o feature@hole_birth=enabled \
    -o feature@large_blocks=enabled -o feature@lz4_compress=enabled \
    -o feature@spacemap_histogram=enabled -o feature@zpool_checkpoint=enabled \
    -O acltype=posixacl -O canmount=off -O compression=lz4 -O devices=off \
    -O normalization=formD -O relatime=on -O xattr=sa ${zpoolnm} /dev/${DEVX}${idx}
  zfs create -o mountpoint=none -o canmount=off ${zpoolnm}/ROOT
  zfs create -o canmount=noauto -o mountpoint=/ ${zpoolnm}/ROOT/default
  zfs mount -o exec,dev ${zpoolnm}/ROOT/default

  zfs create -o com.sun:auto-snapshot=false ${zpoolnm}/tmp
  zfs create -o canmount=off ${zpoolnm}/usr
  zfs create ${zpoolnm}/usr/local
  zfs create ${zpoolnm}/home
  zfs create -o mountpoint=/root ${zpoolnm}/root
  zfs create -o canmount=off ${zpoolnm}/var
  zfs create -o canmount=off ${zpoolnm}/var/lib
  zfs create -o exec=off -o setuid=off -o acltype=posixacl -o xattr=sa \
    ${zpoolnm}/var/log
  zfs create ${zpoolnm}/var/spool
  zfs create -o com.sun:auto-snapshot=false ${zpoolnm}/var/cache
  zfs create -o setuid=off -o com.sun:auto-snapshot=false ${zpoolnm}/var/tmp
  zfs create -o atime=on ${zpoolnm}/var/mail
  zfs create ${zpoolnm}/opt

  zfs set quota=7368M ${zpoolnm}/home
  zfs set quota=5G ${zpoolnm}/var
  zfs set quota=2G ${zpoolnm}/tmp

  zpool set bootfs=${zpoolnm}/ROOT/default ${zpoolnm} # ??
  zpool set cachefile=/etc/zfs/zpool.cache ${zpoolnm} ; sync

  zpool export ${zpoolnm} ; sync ; sleep 3
  zpool import -d /dev/${DEVX}${idx} -R /mnt -N ${zpoolnm}
  zpool import -R /mnt -N ${zpoolnm}
  zfs mount -o exec,dev ${zpoolnm}/ROOT/default ; zfs mount -a ; sync
  zpool set cachefile=/etc/zfs/zpool.cache ${zpoolnm}
  sync ; cat /etc/zfs/zpool.cache ; sleep 3
  mkdir -p /mnt/etc/zfs ; cp /etc/zfs/zpool.cache /mnt/etc/zfs/

  zpool list -v ; sleep 3 ; zfs list ; sleep 3
  zfs mount ; sleep 5
}

lvmpv_create() {
  GRP_NM=${1:-vg0} ; PV_NM=${2:-pvol0}
  PARTS_NM_SZ=${PARTS_NM_SZ:-osRoot:12G osVar:5G osSnap:2100M osHome:7368M}
  modprobe dm-mod ; modprobe dm-crypt ; lvm version
  modinfo dm_mod dm_crypt | grep -e name -e version
  lsmod | grep -e dm_mod -e dm_crypt ; sleep 5

  #DEV_PV=$(blkid | grep -e ${PV_NM} | cut -d: -f1)
  DEV_PV=$(lsblk -nlpo name,partlabel | grep -e ${PV_NM} | cut -d' ' -f1)
  pvcreate ${DEV_PV} ; pvs ; sleep 3
  vgcreate ${GRP_NM} ${DEV_PV} ; vgs ; sleep 3
  for nm_sz in ${PARTS_NM_SZ} ; do
    lv_nm=$(echo ${nm_sz} | cut -d: -f1) ; lv_sz=$(echo ${nm_sz} | cut -d: -f2) ;
    if [ "osHome" = "${lv_nm}" ] ; then
      lvcreate -n ${lv_nm} -l +100%FREE ${GRP_NM} ;
    else
      #lvcreate -Z n -n ${lv_nm} -L ${lv_sz} ${GRP_NM} ;
      lvcreate -n ${lv_nm} -L ${lv_sz} ${GRP_NM} ;
    fi ;
    if [ "osSwap" = "${lv_nm}" ] ; then
      lvchange --contiguous y ${GRP_NM}/osSwap ;
    fi ;
  done
  lvremove -y ${GRP_NM}/osSnap
  vgscan ; vgchange -ay ; sleep 3 ; lvs ; sleep 3
}

btrfspart_create() {
  GRP_NM=${1:-vg0} ; PV_NM=${2:-pvol0}
  modprobe btrfs
  modinfo btrfs | grep -e name -e version
  lsmod | grep -e btrfs ; sleep 5

  #DEV_PV=$(blkid | grep -e ${PV_NM} | cut -d: -f1)
  DEV_PV=$(lsblk -nlpo name,partlabel | grep -e ${PV_NM} | cut -d' ' -f1)
  mkfs.btrfs -L ${PV_NM} ${DEV_PV}
  mkdir -p /mnt ; mount -t btrfs ${DEV_PV} /mnt ; sync

  btrfs quota enable /mnt
  btrfs subvolume create /mnt/@
  btrfs subvolume create /mnt/@/.snapshots
  btrfs subvolume create /mnt/@/var
  btrfs subvolume create /mnt/@/tmp
  btrfs subvolume create /mnt/@/home
  btrfs subvolume set-default 257 /mnt

  btrfs subvolume list /mnt | cut -d' ' -f2 | xargs -I{} -n1 btrfs qgroup create 0/{} /mnt
  sleep 3 ; btrfs quota rescan /mnt
  btrfs qgroup limit 7368M /mnt/@/home
  btrfs qgroup limit 5G /mnt/@/var
  btrfs qgroup limit 2G /mnt/@/tmp
  btrfs qgroup show -re /mnt ; sleep 5

  btrfs device scan
  btrfs filesystem show ; btrfs subvolume list /mnt ; sleep 5
  umount /mnt ; sync
}

format_partitions() {
  VOL_MGR=${1:-std} ; GRP_NM=${2:-vg0} ; PV_NM=${3:-pvol0}
  MKFS_CMD=${MKFS_CMD:-mkfs.ext4}
  PARTS_NM_SZ=${PARTS_NM_SZ:-osRoot:12G osVar:5G osSnap:2100M osHome:7368M}

  echo "Formatting file systems" ; sleep 3
  if [ "${VOL_MGR}" = "zfs" ] ; then
    ZPARTNM_ZPOOLNM=${ZPARTNM_ZPOOLNM:-${GRP_NM}-osPool:ospool0}
    zfspart_create ${ZPARTNM_ZPOOLNM} ;

    DEV_SWAP=$(blkid | grep -e "osSwap" | cut -d: -f1) ;
    yes | mkswap -L "${GRP_NM}-osSwap" ${DEV_SWAP} ;
  elif [ "${VOL_MGR}" = "btrfs" ] ; then
    btrfspart_create ${GRP_NM} ${PV_NM} ;
  else
    if [ "${VOL_MGR}" = "lvm" ] ; then
      lvmpv_create ${GRP_NM} ${PV_NM} ;
    fi ;
    for nm_sz in ${PARTS_NM_SZ} ; do
      lv_nm=$(echo ${nm_sz} | cut -d: -f1) ; lv_sz=$(echo ${nm_sz} | cut -d: -f2) ;
      #DEV_LV=$(blkid | grep -e "${lv_nm}" | cut -d: -f1) ;
      DEV_LV=$(lsblk -nlpo name,label,partlabel | grep -e "${lv_nm}" | cut -d' ' -f1) ;
      if [ "osSwap" = "${lv_nm}" ] ; then
        yes | mkswap -L "${GRP_NM}-${lv_nm}" ${DEV_LV} ;
      else
        yes | ${MKFS_CMD} -L "${GRP_NM}-${lv_nm}" ${DEV_LV} ;
      fi ;
    done ;
  fi
  DEV_SWAP=$(lsblk -nlpo name,label,partlabel | grep -e "osSwap" | cut -d' ' -f1)
  #DEV_ESP=$(blkid | grep -e ESP | cut -d: -f1)
  DEV_ESP=$(lsblk -nlpo name,partlabel | grep -e ESP | cut -d' ' -f1)
  DEV_BOOT=$(lsblk -nlpo name,label,partlabel | grep -e "osBoot" | cut -d' ' -f1)
  sleep 3 ; yes | mkswap -L "${GRP_NM}-osSwap" ${DEV_SWAP}
  sleep 3 ; yes | mkfs.fat -n ESP ${DEV_ESP}
  sleep 3 ; yes | mkfs.ext2 -L "${GRP_NM}-osBoot" ${DEV_BOOT}
  sync
}

part_format() {
  TOOL=${1:-sgdisk} ; VOL_MGR=${2:-std} ; GRP_NM=${3:-vg0} ; PV_NM=${4:-pvol0}
  MKFS_CMD=${MKFS_CMD:-mkfs.ext4}
  PARTS_NM_SZ=${PARTS_NM_SZ:-osRoot:12G osVar:5G osSnap:2100M osHome:7368M}

  part_disk ${TOOL} ${VOL_MGR} ${GRP_NM} ${PV_NM}
  format_partitions ${VOL_MGR} ${GRP_NM} ${PV_NM}
}

mount_filesystems() {
  VOL_MGR=${1:-std} ; GRP_NM=${2:-vg0}

  echo "Mounting file systems" ; sync ; sleep 3
  if [ "zfs" = "${VOL_MGR}" ] ; then
    zfs mount -a ; mkdir -p /mnt/etc/zfs ;

    mkdir -p /mnt/etc /mnt/media ;
  elif [ "btrfs" = "${VOL_MGR}" ] ; then
    DEV_PV=$(lsblk -nlpo name,partlabel | grep -e ${PV_NM:-pvol0} | cut -d' ' -f1) ;
    mount -o noatime,compress=lzo,subvol=@ ${DEV_PV} /mnt ;
    mkdir -p /mnt/.snapshots /mnt/var /mnt/tmp /mnt/home ;
    mount -o noatime,compress=lzo,subvol=@/.snapshots ${DEV_PV} \
      /mnt/.snapshots ;
    mount -o noatime,compress=lzo,subvol=@/var ${DEV_PV} /mnt/var ;
    mount -o noatime,compress=lzo,subvol=@/tmp ${DEV_PV} /mnt/tmp ;
    mount -o noatime,compress=lzo,subvol=@/home ${DEV_PV} /mnt/home ;

    mkdir -p /mnt/etc /mnt/media ;
    sh -c 'cat > /mnt/etc/fstab' << EOF ;
PARTLABEL=${PV_NM:-pvol0}  /          auto    noatime,compress=lzo,subvol=/@   0   0
PARTLABEL=${PV_NM:-pvol0}  /.snapshots  auto    noatime,compress=lzo,subvol=/@/.snapshots   0   0
PARTLABEL=${PV_NM:-pvol0}  /var  auto    noatime,compress=lzo,subvol=/@/var   0   0
PARTLABEL=${PV_NM:-pvol0}  /tmp  auto    noatime,compress=lzo,subvol=/@/tmp   0   0
PARTLABEL=${PV_NM:-pvol0}  /home  auto    noatime,compress=lzo,subvol=/@/home   0   0
EOF
  else
    DEV_ROOT=$(lsblk -nlpo name,label,partlabel | grep -e "${GRP_NM}-osRoot" | cut -d' ' -f1) ;
    DEV_VAR=$(lsblk -nlpo name,label,partlabel | grep -e "${GRP_NM}-osVar" | cut -d' ' -f1) ;
    DEV_HOME=$(lsblk -nlpo name,label,partlabel | grep -e "${GRP_NM}-osHome" | cut -d' ' -f1) ;
    mkdir -p /mnt ; mount ${DEV_ROOT} /mnt ;
    mkdir -p /mnt/root /mnt/var /mnt/home ;
    mount ${DEV_VAR} /mnt/var ; mount ${DEV_HOME} /mnt/home ;

    mkdir -p /mnt/etc /mnt/media ;

    if [ "lvm" = "${VOL_MGR}" ] ; then
      sh -c 'cat > /mnt/etc/fstab' << EOF ;
LABEL=${GRP_NM}-osRoot   /           auto    errors=remount-ro   0   1
LABEL=${GRP_NM}-osVar    /var        auto    defaults    0   2
LABEL=${GRP_NM}-osHome   /home       auto    defaults    0   2
EOF
    else
      sh -c 'cat > /mnt/etc/fstab' << EOF ;
PARTLABEL=${GRP_NM}-osRoot   /           auto    errors=remount-ro   0   1
PARTLABEL=${GRP_NM}-osVar    /var        auto    defaults    0   2
PARTLABEL=${GRP_NM}-osHome   /home       auto    defaults    0   2
EOF
    fi ;
  fi
  chmod 0755 / ; chmod 0755 /mnt/media
  sh -c 'cat >> /mnt/etc/fstab' << EOF ;
PARTLABEL=${GRP_NM}-osBoot   /boot       ext2    defaults    0   2
PARTLABEL=ESP      /boot/efi   vfat    umask=0077  0   2
PARTLABEL=${GRP_NM}-osSwap   none        swap    sw          0   0

proc                            /proc       proc    defaults    0   0
sysfs                           /sys        sysfs   defaults    0   0

#9p_Data0           /media/9p_Data0  9p  trans=virtio,version=9p2000.L,rw,_netdev  0  0

#PARTLABEL=data0    /mnt/Data0   exfat   auto,failok,rw,gid=sudo,uid=0   0    0
#PARTLABEL=data0    /mnt/Data0   exfat   auto,failok,rw,dmask=0000,fmask=0111   0    0

EOF
  DEV_SWAP=$(lsblk -nlpo name,label,partlabel | grep -e "${GRP_NM}-osSwap" | cut -d' ' -f1)
  swapon ${DEV_SWAP}

  DEV_BOOT=$(lsblk -nlpo name,label,partlabel | grep -e "${GRP_NM}-osBoot" | cut -d' ' -f1)
  mkdir -p /mnt/boot ; mount ${DEV_BOOT} /mnt/boot
  #DEV_ESP=$(blkid | grep -e ESP | cut -d: -f1)
  DEV_ESP=$(lsblk -nlpo name,partlabel | grep -e ESP | cut -d' ' -f1)
  mkdir -p /mnt/boot/efi ; mount ${DEV_ESP} /mnt/boot/efi
  sync ; lsblk -l ; sleep 3
}

#----------------------------------------
${@}
