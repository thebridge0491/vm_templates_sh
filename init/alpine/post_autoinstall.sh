#!/bin/sh -x

# nc -l [-p] {port} > file ## nc -w3 {host} {port} < file  # netcat xfr
# ssh user@ipaddr "su -c 'sh -xs - arg1 argN'" < script.sh
# ssh user@ipaddr "sudo sh -xs - arg1 argN" < script.sh  # w/ sudo

set -x

export VOL_MGR=${VOL_MGR:-std}
export GRP_NM=${GRP_NM:-vg0}
export MIRROR=${MIRROR:-dl-cdn.alpinelinux.org/alpine}
#export RELEASE=${RELEASE:-latest-stable}

#ntpd -u ntp:ntp ; ntpq -p ; sleep 3
#rdate -v -a time.nist.gov

export CHROOT_CMD=chroot
if command -v xchroot > /dev/null ; then
  export CHROOT_CMD=xchroot ; # (void: pkg xtools[-minimal])
elif command -v arch-chroot > /dev/null ; then
  export CHROOT_CMD=arch-chroot ; # (archlinux: pkg arch-install-scripts)
elif command -v artix-chroot > /dev/null ; then
  export CHROOT_CMD=artix-chroot ; # (artix: pkg artools-base)
fi

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
    #mount -o noatime,compress=lzo,subvol=@ ${DEV_PV} /mnt ;
    mount -o noatime,compress=lzo ${DEV_PV} /mnt ;
    mkdir -p /mnt/var/log /mnt/var/cache /mnt/var/mail /mnt/var/spool /mnt/var/tmp \
      /mnt/usr/local /mnt/home /mnt/root /mnt/opt /mnt/.snapshots ; #/mnt/tmp ;
    mount -o noatime,compress=lzo,subvol=@/var_log ${DEV_PV} /mnt/var/log ;
    mount -o noatime,compress=lzo,subvol=@/var_cache ${DEV_PV} /mnt/var/cache ;
    mount -o noatime,compress=lzo,subvol=@/var_mail ${DEV_PV} /mnt/var/mail ;
    mount -o noatime,compress=lzo,subvol=@/var_spool ${DEV_PV} /mnt/var/spool ;
    mount -o noatime,compress=lzo,subvol=@/var_tmp ${DEV_PV} /mnt/var/tmp ;
    mount -o noatime,compress=lzo,subvol=@/usr_local ${DEV_PV} /mnt/usr/local ;
    mount -o noatime,compress=lzo,subvol=@/home ${DEV_PV} /mnt/home ;
    mount -o noatime,compress=lzo,subvol=@/root ${DEV_PV} /mnt/root ;
    mount -o noatime,compress=lzo,subvol=@/opt ${DEV_PV} /mnt/opt ;
    #mount -o noatime,compress=lzo,subvol=@/tmp ${DEV_PV} /mnt/tmp ;
    mount -o noatime,compress=lzo,subvol=@/.snapshots ${DEV_PV} \
      /mnt/.snapshots ;

    cp /mnt/etc/fstab /mnt/etc/fstab.old ;
#    sh -c 'cat >> /mnt/etc/fstab' << EOF ;
#PARTLABEL=${PV_NM:-pvol0}  /          auto    noatime,compress=lzo   0   0
#PARTLABEL=${PV_NM:-pvol0}  /var/tmp  auto    noatime,compress=lzo,subvol=@/var_tmp   0   0
#PARTLABEL=${PV_NM:-pvol0}  /var/spool  auto    noatime,compress=lzo,subvol=@/var_spool   0   0
#PARTLABEL=${PV_NM:-pvol0}  /var/mail  auto    noatime,compress=lzo,subvol=@/var_mail   0   0
#PARTLABEL=${PV_NM:-pvol0}  /var/log  auto    noatime,compress=lzo,subvol=@/var_log   0   0
#PARTLABEL=${PV_NM:-pvol0}  /var/cache  auto    noatime,compress=lzo,subvol=@/var_cache   0   0
#PARTLABEL=${PV_NM:-pvol0}  /usr/local  auto    noatime,compress=lzo,subvol=@/usr_local   0   0
#PARTLABEL=${PV_NM:-pvol0}  /home  auto    noatime,compress=lzo,subvol=@/home   0   0
#PARTLABEL=${PV_NM:-pvol0}  /root  auto    noatime,compress=lzo,subvol=@/root   0   0
#PARTLABEL=${PV_NM:-pvol0}  /opt  auto    noatime,compress=lzo,subvol=@/opt   0   0
##PARTLABEL=${PV_NM:-pvol0}  /tmp  auto    noatime,compress=lzo,subvol=@/tmp   0   0
#PARTLABEL=${PV_NM:-pvol0}  /.snapshots  auto    noatime,compress=lzo,subvol=@/.snapshots   0   0
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
  mkdir -p /mnt/boot/efi ; mount ${DEV_ESP} /mnt/boot/efi

  mkdir -p /mnt/boot/efi/EFI/BOOT

  cp /etc/mtab /mnt/etc/mtab
  mkdir -p /mnt/proc /mnt/sys /mnt/dev /mnt/run
  if [ "chroot" = "${CHROOT_CMD}" ] ; then
    echo "Prepare chroot (mount --[r]bind devices)" ; sleep 3

    #mount --rbind /proc /mnt/proc ; mount --rbind /sys /mnt/sys
    #mount --rbind /dev /mnt/dev ; mount --rbind /dev/pts /mnt/dev/pts
    #mount --rbind /run /mnt/run ; mount --rbind /dev/shm /mnt/dev/shm
    for fsX in /proc /sys /dev /dev/pts /run /dev/shm ; do
      mount --rbind ${fsX} /mnt${fsX} ;
    done
  fi
  modprobe efivarfs
  mount -t efivarfs efivarfs /mnt/sys/firmware/efi/efivars/
  mkdir -p /mnt/sys/firmware/efi/efivars /mnt/lib/modules
  sleep 5

  mkdir -p /mnt/media ; chmod 0755 /mnt/media
  sh -c 'cat >> /mnt/etc/fstab' << EOF ;
#PARTLABEL=${GRP_NM}-osBoot   /boot       ext2    defaults    0   2
#PARTLABEL=ESP      /boot/efi   vfat    umask=0077  0   2
PARTLABEL=${GRP_NM}-osSwap   none        swap    sw          0   0

#tmpfs                           /tmp        tmpfs   defaults,nosuid,nodev,mode=1777   0   0
proc                            /proc       proc    defaults    0   0
sysfs                           /sys        sysfs   defaults    0   0

#9p_Data0           /media/9p_Data0  9p  trans=virtio,version=9p2000.L,rw,_netdev  0  0
EOF
}

system_config() {
  #export PASSWD_PLAIN=${1:-packer}
  export PASSWD_CRYPTED=${1:-\$6\$16CHARACTERSSALT\$A4i3yeafzCxgDj5imBx2ZdMWnr9LGzn3KihP9Dz0zTHbxw31jJGEuuJ6OB6Blkkw0VSUkQzSjE9n4iAAnl0RQ1}

  cat << EOFchroot | LANG=en_US.UTF-8 LANGUAGE=en ${CHROOT_CMD} /mnt /bin/sh
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

#services_enabled="# udev udev-trigger udev-settle udev-postmount
networking urandom hostname hwclock modules sysctl bootmisc swap loadkmap mount-ro killprocs savecache devfs dmesg mdev hwdrivers acpid dhcpcd sshd"
# udev udev-trigger udev-settle udev-postmount
services_enabled="dhcpcd sshd"
services_disabled="syslog crond"
pkg_list="eudev eudev-openrc udev-init-scripts lsb-release-minimal man-db man-pages dhcpcd bash sudo mkpasswd util-linux util-linux-misc coreutils tar procps-ng grep iproute2-ss musl-locales pciutils shadow openssh python3 py3-urllib3"
# efibootmgr xfce4

echo "Add software package selection(s)" ; sleep 3
for pkgX in \${pkg_list} ; do
  apk --arch ${UNAME_M} add \${pkgX} ;
done
sleep 5

sed -i "s|^\(iface eth0 inet.*\)$|#\1|g" /etc/network/interfaces

echo "Config services" ; sleep 3

echo "Enable|disable services" ; sleep 3
boot_svcs="networking urandom hostname hwclock modules sysctl bootmisc swap loadkmap syslog rsyslog lvm btrfs-scan"
shutdown_svcs="mount-ro killprocs savecache"
sysinit_svcs="devfs dmesg mdev hwdrivers udev udev-trigger udev-settle zfs-import zfs-mount"
for svc in \${services_enabled} ; do
  if [ "\$(echo \${boot_svcs} | grep \${svc})" ] ; then
    rc-update add \${svc} boot ;
  elif [ "\$(echo \${shutdown_svcs} | grep \${svc})" ] ; then
    rc-update add \${svc} shutdown ;
  elif [ "\$(echo \${sysinit_svcs} | grep \${svc})" ] ; then
    rc-update add \${svc} sysinit ;
  else
    rc-update add \${svc} default ;
  fi ;
done
for svc in \${services_disabled} ; do
  if [ "\$(echo \${boot_svcs} | grep \${svc})" ] ; then
    rc-update del \${svc} boot ;
  elif [ "\$(echo \${shutdown_svcs} | grep \${svc})" ] ; then
    rc-update del \${svc} shutdown ;
  elif [ "\$(echo \${sysinit_svcs} | grep \${svc})" ] ; then
    rc-update del \${svc} sysinit ;
  else
    rc-update del \${svc} default ;
  fi ;
done


echo "Set root passwd ; add user" ; sleep 3
#echo -n "root:${PASSWD_PLAIN}" | chpasswd
echo -n 'root:${PASSWD_CRYPTED}' | chpasswd -e

#DIR_MODE=0750
useradd -m -g users -G wheel -s /bin/bash -c 'Packer User' packer
#echo -n "packer:${PASSWD_PLAIN}" | chpasswd
echo -n 'packer:${PASSWD_CRYPTED}' | chpasswd -e
mkdir -m 0700 -p /home/packer/.ssh ; chown -R packer /home/packer

#sh -c 'cat | EDITOR="tee -a" visudo -f /etc/sudoers.d/99_packernopasswd' << EOF
##Defaults:packer !requiretty
#packer ALL=(ALL:ALL) NOPASSWD: ALL
#
#EOF
##chmod 0440 /etc/sudoers.d/99_packernopasswd
sleep 5


#sed -i '/^%wheel.*(ALL)\s*ALL/ s|%wheel|# %wheel|' /etc/sudoers
#sed -i '/^#.*%wheel.*NOPASSWD.*/ s|^#.*%wheel|%wheel|' /etc/sudoers
#sed -i '/^[^#].*requiretty/ s|^|#|' /etc/sudoers
cat << EOF | EDITOR="tee -a" visudo -f /etc/sudoers.d/99_wheelnopasswd
#Defaults:%wheel !requiretty
%wheel ALL=(ALL:ALL) NOPASSWD: ALL

EOF


#echo "Temporarily permit root login via ssh password" ; sleep 3
#sed -i '/PermitRootLogin/ s|^\(.*\)$|PermitRootLogin yes|' /etc/ssh/sshd_config
#sed -i 's|.*PermitRootLogin|#PermitRootLogin|' /etc/ssh/sshd_config
#echo "PermitRootLogin yes" > /etc/ssh/sshd_config.d/99-rootlogin.conf


apk -v cache clean

mkpasswd -m help ; sleep 10

fstrim -av ; sync

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
