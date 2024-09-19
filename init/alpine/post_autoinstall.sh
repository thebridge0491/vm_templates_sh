#!/bin/sh -x

# nc -l [-p] {port} > file ## nc -w3 {host} {port} < file  # netcat xfr
# ssh user@ipaddr "su -c 'sh -xs - arg1 argN'" < script.sh
# ssh user@ipaddr "sudo sh -xs - arg1 argN" < script.sh  # w/ sudo

set -x

export VOL_MGR=${VOL_MGR:-std}
export GRP_NM=${GRP_NM:-vg0}
export MIRROR=${MIRROR:-dl-cdn.alpinelinux.org/alpine}
#export RELEASE=${RELEASE:-latest-stable}

service sshd stop


remount_filesys0() {
  echo "Re-mount filesystems" ; sleep 3
  DEV_ROOT=$(blkid | grep -e "${GRP_NM}-osRoot" | cut -d: -f1)
  #DEV_ROOT=$(lsblk -nlpo name,label,partlabel | grep -e "${GRP_NM}-osRoot" | cut -d' ' -f1)

  if [ "btrfs" = "${VOL_MGR}" ] ; then
    DEV_PV=$(lsblk -nlpo name,partlabel | grep -e ${PV_NM:-pvol0} | cut -d' ' -f1) ;
    mount -o noatime,compress=lzo,subvol=@ ${DEV_PV} /mnt ;
  elif [ "lvm" = "${VOL_MGR}" ] ; then
    mount /dev/mapper/vg0-lv_root /mnt ;
  else
    mount /dev/sda3 /mnt ;
  fi
  #mount ${DEV_ROOT} /mnt
  sync
}

remount_filesys() {
  echo "Re-mount filesystems" ; sleep 3
  if [ "btrfs" = "${VOL_MGR}" ] ; then
    DEV_PV=$(lsblk -nlpo name,partlabel | grep -e ${PV_NM:-pvol0} | cut -d' ' -f1) ;
    mount -o noatime,compress=lzo,subvol=@ ${DEV_PV} /mnt ;
    mkdir -p /mnt/.snapshots /mnt/var /mnt/tmp \
      /mnt/home ;
    mount -o noatime,compress=lzo,subvol=@/.snapshots ${DEV_PV} \
      /mnt/.snapshots ;
    mount -o noatime,compress=lzo,subvol=@/var ${DEV_PV} /mnt/var ;
    mount -o noatime,compress=lzo,subvol=@/tmp ${DEV_PV} /mnt/tmp ;
    mount -o noatime,compress=lzo,subvol=@/home ${DEV_PV} /mnt/home ;

    cp /mnt/etc/fstab /mnt/etc/fstab.old ;
#    sh -c 'cat >> /mnt/etc/fstab' << EOF ;
#PARTLABEL=${PV_NM:-pvol0}  /          auto    noatime,compress=lzo,subvol=/@   0   0
#PARTLABEL=${PV_NM:-pvol0}  /.snapshots  auto    noatime,compress=lzo,subvol=/@/.snapshots   0   0
#PARTLABEL=${PV_NM:-pvol0}  /var  auto    noatime,compress=lzo,subvol=/@/var   0   0
#PARTLABEL=${PV_NM:-pvol0}  /tmp  auto    noatime,compress=lzo,subvol=/@/tmp   0   0
#PARTLABEL=${PV_NM:-pvol0}  /home  auto    noatime,compress=lzo,subvol=/@/home   0   0
#
#EOF
  elif [ "lvm" = "${VOL_MGR}" ] ; then
    mount /dev/mapper/${GRP_NM}-osRoot /mnt ;
    mount /dev/mapper/${GRP_NM}-osVar /mnt/var ;
    mount /dev/mapper/${GRP_NM}-osHome /mnt/home ;

    echo "Fix /etc/fstab /dev/vgX/osRoot to /dev/mapper/vgX-osRoot, ..." ;
    sed -i "s|${GRP_NM}/|mapper/${GRP_NM}-|g" /mnt/etc/fstab ;
    sleep 3 ;
  else
    DEV_ROOT=$(lsblk -nlpo name,label,partlabel | grep -e "${GRP_NM}-osRoot" | cut -d' ' -f1) ;
    DEV_VAR=$(lsblk -nlpo name,label,partlabel | grep -e "${GRP_NM}-osVar" | cut -d' ' -f1) ;
    DEV_HOME=$(lsblk -nlpo name,label,partlabel | grep -e "${GRP_NM}-osHome" | cut -d' ' -f1) ;
    mount ${DEV_ROOT} /mnt ;
    mount ${DEV_VAR} /mnt/var ;
    mount ${DEV_HOME} /mnt/home ;
  fi

  DEV_BOOT=$(lsblk -nlpo name,label,partlabel | grep -e "${GRP_NM}-osBoot" | cut -d' ' -f1)
  mkdir -p /mnt/boot ; mount ${DEV_BOOT} /mnt/boot
  DEV_ESP=$(lsblk -nlpo name,partlabel | grep -e "/dev/${DEVX}" | grep -e ESP | cut -d' ' -f1)
  mkdir -p /mnt/boot/EFI ; mount ${DEV_ESP} /mnt/boot/EFI

  mkdir -p /mnt/boot/EFI/EFI/BOOT

  echo "Prepare chroot (mount --[r]bind devices)" ; sleep 3
  cp /etc/mtab /mnt/etc/mtab
  mkdir -p /mnt/dev /mnt/proc /mnt/sys /mnt/run /mnt/sys/firmware/efi/efivars /mnt/lib/modules
  mount --rbind /proc /mnt/proc ; mount --rbind /sys /mnt/sys
  mount --rbind /dev /mnt/dev

  mount --rbind /dev/pts /mnt/dev/pts ; mount --rbind /run /mnt/run
  modprobe efivarfs
  mount -t efivarfs efivarfs /mnt/sys/firmware/efi/efivars/


  mkdir -p /mnt/media ; chmod 0755 /mnt/media
  sh -c 'cat >> /mnt/etc/fstab' << EOF ;
#PARTLABEL=${GRP_NM}-osBoot   /boot       ext2    defaults    0   2
#PARTLABEL=ESP      /boot/efi   vfat    umask=0077  0   2
PARTLABEL=${GRP_NM}-osSwap   none        swap    sw          0   0

proc                            /proc       proc    defaults    0   0
sysfs                           /sys        sysfs   defaults    0   0

#9p_Data0           /media/9p_Data0  9p  trans=virtio,version=9p2000.L,rw,_netdev  0  0
EOF

  sleep 5
}

system_config() {
  #export PASSWD_PLAIN=${1:-packer}
  export PASSWD_CRYPTED=${1:-\$6\$16CHARACTERSSALT\$A4i3yeafzCxgDj5imBx2ZdMWnr9LGzn3KihP9Dz0zTHbxw31jJGEuuJ6OB6Blkkw0VSUkQzSjE9n4iAAnl0RQ1}

  cat << EOFchroot | LANG=en_US.UTF-8 LANGUAGE=en chroot /mnt /bin/sh
set -x

chmod 1777 /tmp ; chmod 1777 /var/tmp
chown root:root / ; chmod 0755 /

service sshd stop

mkdir -p /etc/apk
. /etc/os-release
RELEASE=\$(cat /etc/alpine-release | cut -d. -f1-2)
sed -i '/cdrom/ s|^|#|' /etc/apk/repositories
echo "http://${MIRROR}/v\${RELEASE}/main" >> /etc/apk/repositories
#echo "http://${MIRROR}/${RELEASE}/main" >> /etc/apk/repositories
echo "http://${MIRROR}/v\${RELEASE}/community" >> /etc/apk/repositories
apk update
cat /etc/apk/repositories ; sleep 5

echo "Add software package selection(s)" ; sleep 3
apk add bash sudo mkpasswd util-linux shadow openssh # efibootmgr
#apk add xfce4
sleep 5

echo "Add user" ; sleep 3
#DIR_MODE=0750
useradd -m -g users -G wheel -s /bin/bash -c 'Packer User' packer
#echo -n "packer:${PASSWD_PLAIN}" | chpasswd
echo -n 'packer:${PASSWD_CRYPTED}' | chpasswd -e
chown -R packer:\$(id -gn packer) /home/packer

#sh -c 'cat > /etc/sudoers.d/99_packer' << EOF
#Defaults:packer !requiretty
#\$(id -un packer) ALL=(ALL) NOPASSWD: ALL
#
#EOF
#chmod 0440 /etc/sudoers.d/99_packer
sleep 5


sed -i "/^%wheel.*(ALL)\s*ALL/ s|%wheel|# %wheel|" /etc/sudoers
sed -i "/^#.*%wheel.*NOPASSWD.*/ s|^#.*%wheel|%wheel|" /etc/sudoers
sed -i "s|^[^#].*requiretty|# Defaults requiretty|" /etc/sudoers


#echo "Temporarily permit root login via ssh password" ; sleep 3
#sed -i "/PermitRootLogin/ s|^\(.*\)$|PermitRootLogin yes|" /etc/ssh/sshd_config


echo "Enable SSH service"
rc-update add sshd default


apk -v cache clean

mkpasswd -m help ; sleep 10

snapshot_name=\${ID}_\${VERSION_ID}-\$(date -u "+%Y%m%d")

if [ "btrfs" = "${VOL_MGR}" ] ; then
  btrfs subvolume snapshot / /.snapshots/${snapshot_name} ;
  # example remove: btrfs subvolume delete /.snapshots/snap1
  btrfs subvolume list / ;
elif [ "lvm" = "${VOL_MGR}" ] ; then
  lvcreate --snapshot --size 2G --name \${snapshot_name} ${GRP_NM}/osRoot ;
  # example remove: lvremove vg0/snap1
  lvs ;
fi
sleep 5 ; fstrim -av
sync

exit

EOFchroot
# end chroot commands
}

unmount_reboot() {
  read -p "Enter 'y' if ready to unmount & reboot [yN]: " response
  if [ "y" = "${response}" ] || [ "Y" = "${response}" ] ; then
    sync ; swapoff -va ; umount -vR /mnt ;
    reboot ; #poweroff ;
  fi
}

run_postinstall() {
  #PASSWD_PLAIN=${1:-}
  PASSWD_CRYPTED=${1:-}

  remount_filesys
  system_config ${PASSWD_CRYPTED}
  unmount_reboot
}

#----------------------------------------
${@}
