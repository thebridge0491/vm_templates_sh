#!/bin/sh -x

set -x

backupunmount_home() {
  GRP_NM=${1:-vg0} ; MNT=${2:-/}
  mkdir -p ${MNT}root/home_bak ; cp -aR ${MNT}home/* ${MNT}root/home_bak/
  rm -rf ${MNT}home/* ; umount -v ${MNT}home
  swapoff -v $(lsblk -nlpo name,label,partlabel | grep -e "${GRP_NM}-osSwap" | cut -d' ' -f1)
  sync
}

crypt_open() {
  MKFS_CMD=${MKFS_CMD:-mkfs.ext4}
  GRP_NM=${1:-vg0}

  DEV_SWAP=$(lsblk -nlpo name,label,partlabel | grep -e "${GRP_NM}-osSwap" | cut -d' ' -f1)
  DEV_HOME=$(lsblk -nlpo name,label,partlabel | grep -e "${GRP_NM}-osHome" | cut -d' ' -f1)

  depmod -a ; modprobe dm-mod ; modprobe dm-crypt
  lsmod | grep -e dm_mod -e dm_crypt ; sleep 5 ; cryptsetup --version
  #true || dd bs=1m if=/dev/urandom of=${DEV_SWAP}
  #true || dd bs=1m if=/dev/urandom of=${DEV_HOME}

  echo -n vmpacker | cryptsetup luksFormat --key-file - --key-size=256 \
    --cipher=aes-xts-plain64 --iter-time=2000 ${DEV_HOME}
  echo -n vmpacker | cryptsetup --verbose open --type luks --key-file - \
    ${DEV_HOME} cr_${GRP_NM}_home
  sync
  cryptsetup open --type plain --key-file=/dev/urandom --key-size=128 \
    --hash=ripemd160 --cipher=aes-cbc-essiv:sha256 ${DEV_SWAP} cr_${GRP_NM}_swap
  yes | mkswap -L "${GRP_NM}-osSwap" /dev/mapper/cr_${GRP_NM}_swap
  yes | ${MKFS_CMD} -L "${GRP_NM}-osHome" /dev/mapper/cr_${GRP_NM}_home
  sync
}

editcrypt_fstab() {
  GRP_NM=${1:-vg0} ; MNT=${2:-/}

  DEV_SWAP=$(lsblk -nlpo name,label,partlabel | grep -e "${GRP_NM}-osSwap" | cut -d' ' -f1)
  DEV_HOME=$(lsblk -nlpo name,label,partlabel | grep -e "${GRP_NM}-osHome" | cut -d' ' -f1)
  cr_swapopts=',noearly,size=128,hash=ripemd160,cipher=aes-cbc-essiv:sha256'
  sh -c "cat >> ${MNT}etc/crypttab" << EOF
cr_${GRP_NM}_swap ${DEV_SWAP} /dev/urandom swap${cr_swapopts}
cr_${GRP_NM}_home ${DEV_HOME} none luks,tries=3

EOF
  sed -i '/\s*osSwap\s*/ s|^[^#]\(\S*\)\(\s*\)|\/dev\/mapper\/cr_${GRP_NM}_swap\2|' ${MNT}etc/fstab
  sed -i '/\/osHome\s*/ s|^[^#]\(\S*\)\(\s*\)|\/dev\/mapper\/cr_${GRP_NM}_home\2|' ${MNT}etc/fstab
}

addkey_hdrbkup() {
  GRP_NM=${1:-vg0} ; MNT=${2:-/}

  DEV_HOME=$(lsblk -nlpo name,label,partlabel | grep -e "${GRP_NM}-osHome" | cut -d' ' -f1)

  mkdir -p ${MNT}etc/obscure ${MNT}var/obscure
  dd count=1 bs=4096 if=/dev/urandom of=${MNT}etc/obscure/puzzle.dat
  cryptsetup luksDump ${DEV_HOME} ; sleep 5
  echo -n vmpacker | cryptsetup luksAddKey --verbose --key-file - \
    --key-slot 1 ${DEV_HOME} ${MNT}etc/obscure/puzzle.dat
  cryptsetup luksChangeKey --verbose ${DEV_HOME}
  cryptsetup luksHeaderBackup ${DEV_HOME} \
    --header-backup-file ${MNT}var/obscure/osHome.dat
  sed -i '/cr_${GRP_NM}_home/ s|none|\/etc\/obscure\/puzzle.dat|' ${MNT}etc/crypttab
}

mountrestore_home() {
  GRP_NM=${1:-vg0} ; MNT=${2:-/}
  swapon -v /dev/mapper/cr_${GRP_NM}_swap
  mount -v /dev/mapper/cr_${GRP_NM}_home ${MNT}home ; sync
  cp -aR ${MNT}root/home_bak/* ${MNT}home/ ; rm -rf ${MNT}root/home_bak
  #chroot ${MNT} sh -c "chown -R packer:$(id -gn packer) /home/packer"
}

#----------------------------------------
${@}

# encrypted(E) swap/home steps:
#   during disk partitioning: [g]part_disk, mkfs_volumes, mount_volumes, (E) crypt_open, (E) editcrypt_fstab, (E) addkey_hdrbkup
#   post OS install: backupunmount_home, (E) crypt_open, (E) editcrypt_fstab, (E) addkey_hdrbkup, mountrestore_home
