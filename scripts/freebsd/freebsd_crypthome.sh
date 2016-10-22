#!/bin/sh -x

set -x

sysctl kern.geom.debugflags ; sysctl kern.geom.debugflags=16
sysctl kern.geom.label.disk_ident.enable=0
sysctl kern.geom.label.gptid.enable=0
sysctl kern.geom.label.gpt.enable=1

exists_zpool_cache() {
  MNT=${1:-/}
  if [ -e "${MNT}boot/zfs/zpool.cache" ] ; then
    echo "Exiting .. appears to be on ZFS file system" ;
    exit ;
  fi
  echo "Continuing .. appears not to be on ZFS file system"
}

backupunmount_home() {
  MNT=${1:-/}
  exists_zpool_cache $MNT
  mkdir -p ${MNT}root/backups/usr_home ; cp -aR ${MNT}usr/home/* ${MNT}root/backups/usr_home/
  rm -rf ${MNT}usr/home/* ; umount -v ${MNT}usr/home
  swapoff /dev/gpt/fsSwap ; sync
}

crypt_open() {
  exists_zpool_cache
  MKFS_CMD=${MKFS_CMD:-newfs -U}
  kldload crypto ; kldload aesni ; kldload geom_eli
  kldstat | grep -e crypto -e aesni -e geom_eli ; sleep 5 ; geli version
  #true || dd bs=1m if=/dev/random of=/dev/gpt/fsHome
  echo -n vmpacker | geli init -J - -l 256 -e AES-XTS -s 4096 \
    -B none gpt/fsHome
  echo -n vmpacker | geli attach -j - gpt/fsHome
  geli onetime -d -l 128 -e AES-CBC -s 4096 gpt/fsSwap ; sync
  if [ "" != "${MKFS_CMD}" ] ; then
    ${MKFS_CMD} /dev/gpt/fsHome.eli ; sync ;
  fi
}

editcrypt_fstab() {
  MNT=${1:-/}
  exists_zpool_cache $MNT
  
  sysrc -f ${MNT}boot/loader.conf crypto_load="YES"
  sysrc -f ${MNT}boot/loader.conf aesni_load="YES"
  sysrc -f ${MNT}boot/loader.conf geom_eli_load="YES"
  
  cr_swapopts=',ealgo=AES-CBC,keylen=128,sectorsize=4096'
  sed -i '' '/swap/ s|^\(.*\)$|#\1|' ${MNT}etc/fstab
  echo "/dev/gpt/fsSwap.eli  none        swap    sw${cr_swapopts} 0   0" \
    >> ${MNT}etc/fstab
  sed -i '' 's|fsHome|fsHome\.eli|' ${MNT}etc/fstab
}

addkey_hdrbkup() {
  MNT=${1:-/}
  exists_zpool_cache $MNT
  mkdir -p ${MNT}boot/obscure ${MNT}root/backups
  dd count=1 bs=4096 if=/dev/random of=${MNT}boot/obscure/puzzle_gpt_fsHome.dat
  geli dump gpt/fsHome ; sleep 5
  geli setkey -n 1 -P -K ${MNT}boot/obscure/puzzle_gpt_fsHome.dat gpt/fsHome
  geli setkey -n 0 gpt/fsHome
  geli backup -v gpt/fsHome ${MNT}root/backups/gpt_fsHome.eli
  sysrc -f ${MNT}etc/rc.conf geli_gpt_fsHome_flags="-p -k /boot/obscure/puzzle_gpt_fsHome.dat"
}

mountrestore_home() {
  MNT=${1:-/}
  exists_zpool_cache $MNT
  swapon /dev/gpt/fsSwap.eli
  mount -v /dev/gpt/fsHome.eli ${MNT}usr/home ; sync
  cp -aR ${MNT}root/backups/usr_home/* ${MNT}usr/home/ ; rm -rf ${MNT}root/backups/usr_home
  #chroot ${MNT} sh -c "chown -R packer:$(id -gn packer) /usr/home/packer"
}

#----------------------------------------
$@

# encrypted(E) swap/home steps:
#   during disk partitioning: [g]part_disk, mkfs_volumes, mount_volumes, (E) crypt_open, (E) editcrypt_fstab, (E) addkey_hdrbkup
#   post OS install: backupunmount_home, (E) crypt_open, (E) editcrypt_fstab, (E) addkey_hdrbkup, mountrestore_home
