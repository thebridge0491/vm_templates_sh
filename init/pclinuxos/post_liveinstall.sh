#!/bin/sh -x

# nc -l [-p] {port} > file ## nc -w3 {host} {port} < file  # netcat xfr
# ssh user@ipaddr "su -c 'sh -xs - arg1 argN'" < script.sh
# ssh user@ipaddr "sudo sh -xs - arg1 argN" < script.sh  # w/ sudo

set -x
if [ -e /dev/vda ] ; then
  export DEVX=vda ;
elif [ -e /dev/sda ] ; then
  export DEVX=sda ;
fi

export VOL_MGR=${VOL_MGR:-std}
export GRP_NM=${GRP_NM:-vg0}
export MIRROR=${MIRROR:-spout.ussg.indiana.edu/linux/pclinuxos}
export UNAME_M=$(uname -m)


# ifconfig [;ifconfig wlan create wlandev ath0 ; ifconfig wlan0 up scan]
# nmcli device status ; nmcli connection up {ifdev}

#ifdev=$(ip -o link | grep 'link/ether' | grep 'LOWER_UP' | sed -n 's|\S*: \(\w*\):.*|\1|p')


remount_filesys() {
  echo "Re-mount filesystems" ; sleep 3
  if [ "btrfs" = "${VOL_MGR}" ] ; then
    DEV_PV=$(lsblk -nlpo name,partlabel | grep -e ${PV_NM:-pvol0} | cut -d' ' -f1) ;
    mount -o noatime,compress=lzo,subvol=@ ${DEV_PV} /mnt/install ;
    mkdir -p /mnt/install/.snapshots /mnt/install/var /mnt/install/tmp \
      /mnt/install/home ;
    mount -o noatime,compress=lzo,subvol=@/.snapshots ${DEV_PV} \
      /mnt/install/.snapshots ;
    mount -o noatime,compress=lzo,subvol=@/var ${DEV_PV} /mnt/install/var ;
    mount -o noatime,compress=lzo,subvol=@/tmp ${DEV_PV} /mnt/install/tmp ;
    mount -o noatime,compress=lzo,subvol=@/home ${DEV_PV} /mnt/install/home ;

    cp /mnt/install/etc/fstab /mnt/install/etc/fstab.old ;
    sh -c 'cat >> /mnt/install/etc/fstab' << EOF ;
PARTLABEL=${PV_NM:-pvol0}  /          auto    noatime,compress=lzo,subvol=/@   0   0
PARTLABEL=${PV_NM:-pvol0}  /.snapshots  auto    noatime,compress=lzo,subvol=/@/.snapshots   0   0
PARTLABEL=${PV_NM:-pvol0}  /var  auto    noatime,compress=lzo,subvol=/@/var   0   0
PARTLABEL=${PV_NM:-pvol0}  /tmp  auto    noatime,compress=lzo,subvol=/@/tmp   0   0
PARTLABEL=${PV_NM:-pvol0}  /home  auto    noatime,compress=lzo,subvol=/@/home   0   0

PARTLABEL=${GRP_NM}-osBoot   /boot       ext2    defaults    0   2
PARTLABEL=ESP      /boot/efi   vfat    umask=0077  0   2
PARTLABEL=${GRP_NM}-osSwap   none        swap    sw          0   0
EOF
  elif [ "lvm" = "${VOL_MGR}" ] ; then
    mount /dev/mapper/${GRP_NM}-osRoot /mnt/install ;
    mount /dev/mapper/${GRP_NM}-osVar /mnt/install/var ;
    mount /dev/mapper/${GRP_NM}-osHome /mnt/install/home ;

    echo "Fix /etc/fstab /dev/vgX/osRoot to /dev/mapper/vgX-osRoot, ..." ;
    sed -i "s|${GRP_NM}/|mapper/${GRP_NM}-|g" /mnt/install/etc/fstab ;
    sleep 3 ;
  else
    DEV_ROOT=$(lsblk -nlpo name,label,partlabel | grep -e "${GRP_NM}-osRoot" | cut -d' ' -f1) ;
    DEV_VAR=$(lsblk -nlpo name,label,partlabel | grep -e "${GRP_NM}-osVar" | cut -d' ' -f1) ;
    DEV_HOME=$(lsblk -nlpo name,label,partlabel | grep -e "${GRP_NM}-osHome" | cut -d' ' -f1) ;
    mount ${DEV_ROOT} /mnt/install ;
    mount ${DEV_VAR} /mnt/install/var ;
    mount ${DEV_HOME} /mnt/install/home ;
  fi

  DEV_BOOT=$(lsblk -nlpo name,label,partlabel | grep -e "${GRP_NM}-osBoot" | cut -d' ' -f1)
  mkdir -p /mnt/install/boot ; mount ${DEV_BOOT} /mnt/install/boot
  DEV_ESP=$(lsblk -nlpo name,partlabel | grep -e "/dev/${DEVX}" | grep -e ESP | cut -d' ' -f1)
  mkdir -p /mnt/install/boot/EFI ; mount ${DEV_ESP} /mnt/install/boot/EFI

  mkdir -p /mnt/install/boot/EFI/EFI/BOOT

  echo "Prepare chroot (mount --[r]bind devices)" ; sleep 3
  cp /etc/mtab /mnt/install/etc/mtab
  mkdir -p /mnt/install/dev /mnt/install/proc /mnt/install/sys /mnt/install/run /mnt/install/sys/firmware/efi/efivars /mnt/install/lib/modules
  mount --rbind /proc /mnt/install/proc ; mount --rbind /sys /mnt/install/sys
  mount --rbind /dev /mnt/install/dev

  mount --rbind /dev/pts /mnt/install/dev/pts ; mount --rbind /run /mnt/install/run
  modprobe efivarfs
  mount -t efivarfs efivarfs /mnt/install/sys/firmware/efi/efivars/


  mkdir -p /mnt/install/media ; chmod 0755 /mnt/install/media
  sh -c 'cat >> /mnt/install/etc/fstab' << EOF

proc                            /proc       proc    defaults    0   0
sysfs                           /sys        sysfs   defaults    0   0

#9p_Data0           /media/9p_Data0  9p  trans=virtio,version=9p2000.L,rw,_netdev  0  0

EOF

  mkdir -p /mnt/install/var/empty /mnt/install/var/lock/subsys /mnt/install/etc/sysconfig/network-scripts
  #cp /etc/sysconfig/network-scripts/ifcfg-${ifdev} /mnt/etc/sysconfig/network-scripts/ifcfg-${ifdev}.bak
  cp /etc/resolv.conf /mnt/install/etc/resolv.conf
  sleep 5
}

system_config() {
  export INIT_HOSTNAME=${1:-pclinuxos-boxv0000}
  export PASSWD_PLAIN=${2:-packer}
  #export PASSWD_CRYPTED=${2:-\$6\$16CHARACTERSSALT\$A4i3yeafzCxgDj5imBx2ZdMWnr9LGzn3KihP9Dz0zTHbxw31jJGEuuJ6OB6Blkkw0VSUkQzSjE9n4iAAnl0RQ1}

  # LANG=[C|en_US].UTF-8
  cat << EOFchroot | LANG=C.UTF-8 LANGUAGE=en chroot /mnt/install /bin/sh
set -x

chmod 1777 /tmp ; chmod 1777 /var/tmp
chown root:root / ; chmod 0755 /

#unset LC_ALL
#export TERM=xterm-color     # xterm | xterm-color
##hostname ${INIT_HOSTNAME}

ls /proc ; sleep 5 ; ls /dev ; sleep 5

#mount -t proc none /proc
#cd /dev ; MAKEDEV generic


echo "Config pkg repo mirror(s)" ; sleep 3
if [ -e /etc/os-release ] ; then
. /etc/os-release
fi
#sed -i 's|^[ ]*rpm|# rpm|' /etc/apt/sources.list
#sed -i "/${MIRROR}/ s|^.*rpm|rpm|" /etc/apt/sources.list
grep -e '^rpm.*' /etc/apt/sources.list ; sleep 5


echo "Add software package selection(s)" ; sleep 3
apt-get -y update
apt-get -y --fix-broken install

pkgs_nms="basesystem-minimal pclinuxos-release bash apt rpm locales-en sudo whois dhcp-client man-pages nano dosfstools xfsprogs lib64hal1" # task-xfce"
apt-get -y install \${pkgs_nms}
# fix AND re-attempt install for infrequent errors
apt-get -y --fix-broken install
apt-get -y install \${pkgs_nms}


#echo "Config keyboard ; localization" ; sleep 3
#kbd_mode -u ; loadkeys us
##sed -i '/en_US.UTF-8 UTF-8/ s|^# ||' /etc/locale.gen
##echo 'LANG=en_US.UTF-8' >> /etc/locale.conf
##locale-gen # en_US en_US.UTF-8

#sh -c 'cat >> /etc/default/locale' << EOF
#LANG=en_US.UTF-8
##LC_ALL=en_US.UTF-8
#LANGUAGE="en_US:en"
#
#EOF


#echo "Config time zone & clock" ; sleep 3
#rm /etc/localtime
#ln -sf /usr/share/zoneinfo/UTC /etc/localtime
#hwclock --systohc --utc


echo "Config hostname ; network" ; sleep 3
echo "${INIT_HOSTNAME}" > /etc/hostname ; hostname -F /etc/hostname
#resolvconf -u   # generates /etc/resolv.conf
#sh -c 'cat >> /etc/resolv.conf' << EOF
##search hqdom.local
#nameserver 8.8.8.8
#
#EOF
cat /etc/resolv.conf ; sleep 5
sed -i '/127.0.1.1/d' /etc/hosts
echo "127.0.1.1    ${INIT_HOSTNAME}.localdomain    ${INIT_HOSTNAME}" >> /etc/hosts

ifdev=\$(ip -o link | grep 'link/ether' | grep 'LOWER_UP' | sed -n 's|\S*: \(\w*\):.*|\1|p')

sh -c "cat >> /etc/sysconfig/network-scripts/ifcfg-\${ifdev}" << EOF
#DEVICE=\${ifdev}
#BOOTPROTO=dhcp
#STARTMODE=auto
#ONBOOT=yes
DHCP_CLIENT=dhclient

EOF

sh -c "cat >> /etc/sysconfig/network" << EOF
#NETWORKING=yes
#CRDA_DOMAIN=US
#HOSTNAME=${INIT_HOSTNAME}

EOF


echo "Update services" ; sleep 3
#drakfirewall ; sleep 5 ; service shorewall stop ; service shorewall6 stop
service -s ; service --status-all ; sleep 5


echo "Adjust PAM for simplistic passwords" ; sleep 3
sed -i '/^password.*required.*cracklib/ s|^|#|' /etc/pam.d/system-auth
sed -i '/^password.*sufficient/ s| use_authtok||' /etc/pam.d/system-auth

echo "Set root passwd ; add user" ; sleep 3
groupadd --system wheel
echo -n "root:${PASSWD_PLAIN}" | chpasswd
#echo -n 'root:${PASSWD_CRYPTED}' | chpasswd -e

DIR_MODE=0750 useradd -m -G wheel -s /bin/bash -c 'Packer User' packer
echo -n "packer:${PASSWD_PLAIN}" | chpasswd
#echo -n 'packer:${PASSWD_CRYPTED}' | chpasswd -e
chown -R packer:\$(id -gn packer) /home/packer
DIR_MODE=0750 useradd -m -G wheel -s /bin/bash -c 'Packer User' packer
echo -n "packer:${PASSWD_PLAIN}" | chpasswd
#echo -n 'packer:${PASSWD_CRYPTED}' | chpasswd -e
chown -R packer:\$(id -gn packer) /home/packer

#sh -c 'cat >> /etc/sudoers.d/99_packer' << EOF
#Defaults:packer !requiretty
#\$(id -un packer) ALL=(ALL) NOPASSWD: ALL
#EOF
#chmod 0440 /etc/sudoers.d/99_packer


sed -i "/^%wheel.*(ALL)\s*ALL/ s|%wheel|# %wheel|" /etc/sudoers
sed -i "/^#.*%wheel.*NOPASSWD.*/ s|^#.*%wheel|%wheel|" /etc/sudoers
echo '%wheel ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers
sed -i "s|^[^#].*requiretty|# Defaults requiretty|" /etc/sudoers


apt-get --fix-broken install -y
# install/enable ssh after reboot
#apt-get install -y openssh-server
service sshd stop #; service network stop


apt-get -y clean

exit

EOFchroot
# end chroot commands
}

bootloader() {
  # LANG=[C|en_US].UTF-8
  cat << EOFchroot | LANG=C.UTF-8 LANGUAGE=en chroot /mnt/install /bin/sh
set -x

if [ -e /etc/os-release ] ; then
. /etc/os-release
fi

pkgs_nms="mkinitrd bootloader grub2 grub2-efi microcode_ctl efibootmgr"
apt-get -y install \${pkgs_nms}
# fix AND re-attempt install for infrequent errors
apt-get -y --fix-broken install
apt-get -y install \${pkgs_nms}

modprobe vfat ; lsmod | grep -e fat ; sleep 5

if [ "btrfs" = "${VOL_MGR}" ] ; then
  apt-get -y install btrfs-progs ;
  apt-get -y --fix-broken install ;
  apt-get -y install btrfs-progs ;
  modprobe btrfs ; sleep 5 ;
elif [ "lvm" = "${VOL_MGR}" ] ; then
  apt-get -y install lvm2 ;
  apt-get -y --fix-broken install ;
  apt-get -y install lvm2 ;
  # cryptsetup
  modprobe dm-mod ; vgscan ; vgchange -ay ; lvs ; sleep 5 ;
fi

kver="\$(ls -A /lib/modules/ | tail -1)" # or ? $(uname -r)
mkinitrd /boot/initrd-\${kver} \${kver}


grub2-probe /boot

echo "Bootloader installation & config" ; sleep 3
mkdir -p /boot/EFI/EFI/\${ID} /boot/EFI/EFI/BOOT
grub2-install --target=x86_64-efi --efi-directory=/boot/EFI --bootloader-id=\${ID} --recheck --removable
grub2-install --target=i386-pc --recheck /dev/${DEVX}
cp -R /boot/EFI/EFI/\${ID}/* /boot/EFI/EFI/BOOT/
cp /boot/EFI/EFI/BOOT/BOOTX64.EFI /boot/EFI/EFI/BOOT/BOOTX64.EFI.bak
cp /boot/EFI/EFI/BOOT/grubx64.EFI /boot/EFI/EFI/BOOT/BOOTX64.EFI

#sed -i -e "s|^GRUB_TIMEOUT=.*$|GRUB_TIMEOUT=1|" /etc/default/grub
#sed -i -e "/GRUB_DEFAULT/ s|=.*$|=saved|" /etc/default/grub
#echo "GRUB_SAVEDEFAULT=true" >> /etc/default/grub
#echo "#GRUB_CMDLINE_LINUX='cryptdevice=/dev/sda2:cryptroot'" >> /etc/default/grub
sed -i '/GRUB_CMDLINE_LINUX_DEFAULT/ s|="\(.*\)"|="\1 nokmsboot noacpi text xdriver=vesa nomodeset rootdelay=5"|'  \
  /etc/default/grub

if [ "btrfs" = "${VOL_MGR}" ] ; then
  echo 'GRUB_PRELOAD_MODULES="btrfs"' >> /etc/default/grub ;
elif [ "lvm" = "${VOL_MGR}" ] ; then
  echo 'GRUB_PRELOAD_MODULES="lvm"' >> /etc/default/grub ;
fi

if [ "\$(dmesg | grep -ie 'Hypervisor detected')" ] ; then
  sed -i -e '/GRUB_CMDLINE_LINUX_DEFAULT/ s|="\(.*\)"|="\1 net.ifnames=0 biosdevname=0"|' /etc/default/grub ;
fi
grub2-mkconfig -o /boot/grub2/grub.cfg
#cp -f /boot/EFI/EFI/\${ID}/grub.cfg /boot/grub2/grub.cfg
#cp -f /boot/EFI/EFI/\${ID}/grub.cfg /boot/EFI/EFI/BOOT/grub.cfg

efibootmgr -c -d /dev/${DEVX} -p \$(lsblk -nlpo name,label,partlabel | sed -n '/ESP/ s|.*[sv]da\([0-9]*\).*|\1|p') -l "/EFI/\${ID}/grubx64.efi" -L \${ID}
efibootmgr -c -d /dev/${DEVX} -p \$(lsblk -nlpo name,label,partlabel | sed -n '/ESP/ s|.*[sv]da\([0-9]*\).*|\1|p') -l "/EFI/BOOT/BOOTX64.EFI" -L Default
efibootmgr -v ; sleep 3

whois-mkpasswd -m help ; sleep 10

exit

EOFchroot

  . /mnt/install/etc/os-release
  snapshot_name=${ID}_${VERSION}-$(date -u "+%Y%m%d")

  if [ "btrfs" = "${VOL_MGR}" ] ; then
    btrfs subvolume snapshot /mnt/install /mnt/install/.snapshots/${snapshot_name} ;
    # example remove: btrfs subvolume delete /.snapshots/snap1
    btrfs subvolume list /mnt/install ;
  elif [ "lvm" = "${VOL_MGR}" ] ; then
    lvcreate --snapshot --size 2G --name ${snapshot_name} ${GRP_NM}/osRoot ;
    # example remove: lvremove vg0/snap1
    lvs ;
  fi
  sleep 5 ; fstrim -av
  sync
}

unmount_reboot() {
  read -p "Enter 'y' if ready to unmount & reboot [yN]: " response
  if [ "y" = "${response}" ] || [ "Y" = "${response}" ] ; then
    sync ; swapoff -va ; umount -vR /mnt/install ;
    reboot ; #poweroff ;
  fi
}

run_postinstall() {
  INIT_HOSTNAME=${1:-}
  PASSWD_PLAIN=${2:-}
  #PASSWD_CRYPTED=${2:-}

  remount_filesys
  system_config ${INIT_HOSTNAME} ${PASSWD_PLAIN}
  #bootloader
  unmount_reboot
}

#----------------------------------------
${@}
