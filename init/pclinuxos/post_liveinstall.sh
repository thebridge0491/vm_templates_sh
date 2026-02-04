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

export DNFCMD="dnf --setopt=install_weak_deps=False"


# ifconfig [; ifconfig wlan create wlandev ath0 ; ifconfig wlan0 up scan]
# nmcli device status ; nmcli connection up {ifdev}

#ntpd -u ntp:ntp ; ntpq -p ; sleep 3
#ntpdate -v -u -b us.pool.ntp.org

#ifdev=$(ip -o link | grep 'link/ether' | grep 'LOWER_UP' | sed -n 's|\S*: \(\w*\):.*|\1|p')


export CHROOT_CMD=chroot

remount_filesys() {
  echo "Re-mount filesystems" ; mkdir -p /mnt/install ; sleep 3
  if [ "btrfs" = "${VOL_MGR}" ] ; then
    DEV_PV=$(lsblk -nlpo name,partlabel | grep -e ${PV_NM:-pvol0} | cut -d' ' -f1) ;
    #mount -o noatime,compress=lzo,subvol=@ ${DEV_PV} /mnt/install ;
    mount -o noatime,compress=lzo ${DEV_PV} /mnt/install ;
    mkdir -p /mnt/install/var/log /mnt/install/var/cache /mnt/install/var/mail \
      /mnt/install/var/spool /mnt/install/var/tmp /mnt/install/usr/local \
      /mnt/install/home /mnt/install/root /mnt/install/opt /mnt/install/.snapshots ; #/mnt/install/tmp ;
    mount -o noatime,compress=lzo,subvol=@/var_log ${DEV_PV} /mnt/install/var/log ;
    mount -o noatime,compress=lzo,subvol=@/var_cache ${DEV_PV} /mnt/install/var/cache ;
    mount -o noatime,compress=lzo,subvol=@/var_mail ${DEV_PV} /mnt/install/var/mail ;
    mount -o noatime,compress=lzo,subvol=@/var_spool ${DEV_PV} /mnt/install/var/spool ;
    mount -o noatime,compress=lzo,subvol=@/var_tmp ${DEV_PV} /mnt/install/var/tmp ;
    mount -o noatime,compress=lzo,subvol=@/usr_local ${DEV_PV} /mnt/install/usr/local ;
    mount -o noatime,compress=lzo,subvol=@/home ${DEV_PV} /mnt/install/home ;
    mount -o noatime,compress=lzo,subvol=@/root ${DEV_PV} /mnt/install/root ;
    mount -o noatime,compress=lzo,subvol=@/opt ${DEV_PV} /mnt/install/opt ;
    #mount -o noatime,compress=lzo,subvol=@/tmp ${DEV_PV} /mnt/install/tmp ;
    mount -o noatime,compress=lzo,subvol=@/.snapshots ${DEV_PV} \
      /mnt/install/.snapshots ;

    cp /mnt/install/etc/fstab /mnt/install/etc/fstab.old ;
    sh -c 'cat >> /mnt/install/etc/fstab' << EOF ;
PARTLABEL=${PV_NM:-pvol0}  /          auto    noatime,compress=lzo   0   0
PARTLABEL=${PV_NM:-pvol0}  /var/tmp  auto    noatime,compress=lzo,subvol=@/var_tmp   0   0
PARTLABEL=${PV_NM:-pvol0}  /var/spool  auto    noatime,compress=lzo,subvol=@/var_spool   0   0
PARTLABEL=${PV_NM:-pvol0}  /var/mail  auto    noatime,compress=lzo,subvol=@/var_mail   0   0
PARTLABEL=${PV_NM:-pvol0}  /var/log  auto    noatime,compress=lzo,subvol=@/var_log   0   0
PARTLABEL=${PV_NM:-pvol0}  /var/cache  auto    noatime,compress=lzo,subvol=@/var_cache   0   0
PARTLABEL=${PV_NM:-pvol0}  /usr/local  auto    noatime,compress=lzo,subvol=@/usr_local   0   0
PARTLABEL=${PV_NM:-pvol0}  /home  auto    noatime,compress=lzo,subvol=@/home   0   0
PARTLABEL=${PV_NM:-pvol0}  /root  auto    noatime,compress=lzo,subvol=@/root   0   0
PARTLABEL=${PV_NM:-pvol0}  /opt  auto    noatime,compress=lzo,subvol=@/opt   0   0
#PARTLABEL=${PV_NM:-pvol0}  /tmp  auto    noatime,compress=lzo,subvol=@/tmp   0   0
PARTLABEL=${PV_NM:-pvol0}  /.snapshots  auto    noatime,compress=lzo,subvol=@/.snapshots   0   0

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
  mkdir -p /mnt/install/boot/efi ; mount ${DEV_ESP} /mnt/install/boot/efi

  mkdir -p /mnt/install/boot/efi/EFI/BOOT

  #cp /etc/mtab /mnt/install/etc/mtab
  mkdir -p /mnt/install/proc /mnt/install/sys /mnt/install/dev \
    /mnt/install/run
  mkdir -p /mnt/install/sys/firmware/efi/efivars /mnt/install/lib/modules \
    /mnt/install/var/empty /mnt/install/var/lock/subsys \
    /mnt/install/etc/sysconfig/network-scripts
  #cp -a /etc/sysconfig/network-scripts/ifcfg-${ifdev} /mnt/install/etc/sysconfig/network-scripts/ifcfg-${ifdev}.bak
  mkdir -p /mnt/install/media ; chmod 0755 /mnt/install/media
  sh -c 'cat >> /mnt/install/etc/fstab' << EOF

tmpfs                           /tmp        tmpfs   defaults,nosuid,nodev,mode=1777   0   0
proc                            /proc       proc    defaults    0   0
sysfs                           /sys        sysfs   defaults    0   0

#9p_Data0           /media/9p_Data0  9p  trans=virtio,version=9p2000.L,rw,_netdev  0  0

EOF

  if [ "chroot" = "${CHROOT_CMD}" ] ; then
    echo "Prepare chroot (mount --[r]bind devices)" ; sleep 3
    cp /etc/resolv.conf /mnt/install/etc/resolv.conf

    #mount --rbind /proc /mnt/install/proc ; mount --rbind /sys /mnt/install/sys
    #mount --rbind /dev /mnt/install/dev ; mount --rbind /dev/pts /mnt/install/dev/pts
    #mount --rbind /run /mnt/install/run ; mount --rbind /dev/shm /mnt/install/dev/shm
    for fsX in /proc /sys /dev /dev/pts /run /dev/shm ; do
      mount --rbind ${fsX} /mnt/install${fsX} ;
    done
  fi
  modprobe efivarfs
  mount -t efivarfs efivarfs /mnt/install/sys/firmware/efi/efivars/
  sleep 5
}

system_config() {
  export INIT_HOSTNAME=${1:-pclinuxos-boxv0000}
  export PASSWD_PLAIN=${2:-packer}
  #export PASSWD_CRYPTED=${2:-\$6\$16CHARACTERSSALT\$A4i3yeafzCxgDj5imBx2ZdMWnr9LGzn3KihP9Dz0zTHbxw31jJGEuuJ6OB6Blkkw0VSUkQzSjE9n4iAAnl0RQ1}

  # LANG=[C|en_US].UTF-8
  cat << EOFchroot | LANG=C.UTF-8 LANGUAGE=en ${CHROOT_CMD} /mnt/install /bin/sh
set -x

# ?? /var/tmp may be sym-link to /tmp ??
rm -r /var/tmp ; mkdir -p /var/tmp
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
if command -v dnf > /dev/null ; then
  ${DNFCMD} --releasever=${RELEASE:-2025} -y check-update ;
  #${DNFCMD} --releasever=${RELEASE:-2025} --refresh -y distro-sync ;
  ${DNFCMD} -y repolist enabled ;
else
  #sed -i 's|^[ ]*rpm|# rpm|' /etc/apt/sources.list ;
  #sed -i "/${MIRROR}/ s|^.*rpm|rpm|" /etc/apt/sources.list ;
  grep -e '^rpm.*' /etc/apt/sources.list ;
fi
sleep 5


services_enabled="sshd"
pkg_list="basesystem-minimal bash apt rpm dnf python3-dnf locales-en sudo whois dhcpcd man-pages nano dosfstools xfsprogs iptables-nft lib64hal1 python3-urllib3"
# openssh-server task-xfce

echo "Add software package selection(s)" ; sleep 3
if command -v dnf > /dev/null ; then
  ${DNFCMD} --releasever=${RELEASE:-2025} -y check-update ;
  ${DNFCMD} --releasever=${RELEASE:-2025} --skip-broken -y install \${pkg_list} ;
else
  apt-get -y update ; apt-get --fix-broken -y install ;
  for pkgX in \${pkg_list} ; do
    apt-get -y install \${pkgX} ;
  done ;
  # fix AND re-attempt install for infrequent errors
  apt-get --fix-broken -y install ;
  for pkgX in \${pkg_list} ; do
    apt-get -y install \${pkgX} ;
  done ;
fi


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
sed -i '/^127.0.1.1/ s|127.0.1.1|#127.0.1.1|' /etc/hosts
echo "127.0.1.1   ${INIT_HOSTNAME}.localdomain  ${INIT_HOSTNAME}" >> /etc/hosts

ifdev=\$(ip -o link | grep 'link/ether' | grep 'LOWER_UP' | sed -n 's|\S*: \(\w*\):.*|\1|p')

#sh -c "cat >> /etc/sysconfig/network-scripts/ifcfg-\${ifdev:-eth0}" << EOF
#DEVICE=\${ifdev:-eth0}
#BOOTPROTO=dhcp
#STARTMODE=auto
#ONBOOT=yes
#DHCP_CLIENT=dhclient
#
#EOF
#sh -c "cat >> /etc/sysconfig/network" << EOF
#NETWORKING=yes
#CRDA_DOMAIN=US
#HOSTNAME=${INIT_HOSTNAME}
#
#EOF
sed -i 's|^HOSTNAME|#HOSTNAME|' /etc/sysconfig/network


echo "Config services" ; sleep 3

echo "Enable services" ; sleep 3
#drakfirewall ; sleep 5
for svc in \${services_enabled} ; do
  chkconfig --add \${svc} ;
done
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
chown -R packer /home/packer
DIR_MODE=0750 useradd -m -G wheel -s /bin/bash -c 'Packer User' packer
echo -n "packer:${PASSWD_PLAIN}" | chpasswd
#echo -n 'packer:${PASSWD_CRYPTED}' | chpasswd -e
mkdir -m 0700 -p /home/packer/.ssh ; chown -R packer /home/packer

#sh -c 'cat | EDITOR="tee -a" visudo -f /etc/sudoers.d/99_packernopasswd' << EOF
##Defaults:packer !requiretty
#packer ALL=(ALL) NOPASSWD: ALL
#
#EOF
##chmod 0440 /etc/sudoers.d/99_packernopasswd


#sed -i '/^[^#].*requiretty/ s|^|#|' /etc/sudoers
cat << EOF | EDITOR="tee -a" visudo -f /etc/sudoers.d/99_wheelnopasswd
#Defaults:%wheel !requiretty
%wheel ALL=(ALL:ALL) NOPASSWD: ALL

EOF


if ! command -v dnf > /dev/null ; then
  apt-get --fix-broken -y  install ;
fi
# install/enable ssh after reboot
#if command -v dnf > /dev/null ; then
#  ${DNFCMD} --releasever=${RELEASE:-2025} --skip-broken -y install openssh-server ;
#else
#  apt-get -y install openssh-server ;
#fi
service sshd stop #; service network stop


if command -v dnf > /dev/null ; then
  ${DNFCMD} -y clean packages ;
else
  apt-get -y clean ;
fi

exit

EOFchroot
# end chroot commands
}

bootloader() {
  # LANG=[C|en_US].UTF-8
  cat << EOFchroot | LANG=C.UTF-8 LANGUAGE=en ${CHROOT_CMD} /mnt/install /bin/sh
set -x

if [ -e /etc/os-release ] ; then
. /etc/os-release
fi

pkg_list="mkinitrd bootloader grub2 grub2-efi efibootmgr" # microcode_ctl

if command -v dnf > /dev/null ; then
  ${DNFCMD} -y check-update ;

  ${DNFCMD} --skip-broken -y install \${pkg_list} ;
else
  for pkgX in \${pkg_list} ; do
    apt-get -y install \${pkgX} ;
  done ;
  # fix AND re-attempt install for infrequent errors
  apt-get --fix-broken -y install ;
  for pkgX in \${pkg_list} ; do
    apt-get -y install \${pkgX} ;
  done ;
fi

kver="\$(ls -A /lib/modules/ | tail -1)" # or ? uname -r
echo \${kver} ; sleep 5

modprobe vfat ; lsmod | grep -e fat ; sleep 5

if [ "btrfs" = "${VOL_MGR}" ] ; then
  if command -v dnf > /dev/null ; then
    ${DNFCMD} --skip-broken -y install btrfs-progs ;
  else
    apt-get -y install btrfs-progs ;
    apt-get --fix-broken -y install ; apt-get -y install btrfs-progs ;
  fi ;
  modprobe btrfs ; sleep 5 ;
elif [ "lvm" = "${VOL_MGR}" ] ; then
  if command -v dnf > /dev/null ; then
    ${DNFCMD} --skip-broken -y install lvm2 ;
  else
    apt-get -y install lvm2 ;
    # cryptsetup
    apt-get --fix-broken -y install ; apt-get -y install lvm2 ;
  fi ;
  modprobe dm-mod ; vgscan ; vgchange -ay ; lvs ; sleep 5 ;
fi

#mkinitrd /boot/initrd-\${kver}.img \${kver}


grub2-probe /boot

echo "Bootloader installation & config" ; sleep 3
mkdir -p /boot/efi/EFI/\${ID} /boot/efi/EFI/BOOT
grub2-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=\${ID} --recheck --removable
grub2-install --target=i386-pc --recheck /dev/${DEVX}
#cp -R /boot/efi/EFI/\${ID}/* /boot/efi/EFI/BOOT/
#cp /boot/efi/EFI/BOOT/BOOTX64.EFI /boot/efi/EFI/BOOT/BOOTX64.EFI.bak
#cp /boot/efi/EFI/BOOT/grubx64.EFI /boot/efi/EFI/BOOT/BOOTX64.EFI
find / -ipath /boot/efi/*/*.efi ; sleep 5

#sed -ie 's|^GRUB_TIMEOUT=.*$|GRUB_TIMEOUT=1|' /etc/default/grub
#sed -ie '/GRUB_DEFAULT/ s|=.*$|=saved|' /etc/default/grub
#echo "GRUB_SAVEDEFAULT=true" >> /etc/default/grub
#echo "#GRUB_CMDLINE_LINUX='cryptdevice=/dev/sda2:cryptroot'" >> /etc/default/grub
sed -ie '/^GRUB_CMDLINE_LINUX_DEFAULT/ s|^\(.*\)$|#\1\n\1|' /etc/default/grub
sed -ie '/^GRUB_CMDLINE_LINUX_DEFAULT/ s|="\(.*\)"|="\1 nokmsboot noacpi xdriver=vesa rootdelay=5 nomodeset text"|'  \
  /etc/default/grub

if [ "btrfs" = "${VOL_MGR}" ] ; then
  echo 'GRUB_PRELOAD_MODULES="btrfs"' >> /etc/default/grub ;
elif [ "lvm" = "${VOL_MGR}" ] ; then
  echo 'GRUB_PRELOAD_MODULES="lvm"' >> /etc/default/grub ;
fi

if [ "\$(dmesg | grep -iE 'kvm|qemu|hypervisor')" ] ; then
  sed -ie '/^GRUB_CMDLINE_LINUX_DEFAULT/ s|="\(.*\)"|="\1 net.ifnames=0 biosdevname=0"|' /etc/default/grub ;
fi
grub2-mkconfig -o /boot/grub2/grub.cfg
#cp -f /boot/efi/EFI/\${ID}/grub.cfg /boot/grub2/grub.cfg
#cp -f /boot/efi/EFI/\${ID}/grub.cfg /boot/efi/EFI/BOOT/grub.cfg

efibootmgr -c -d /dev/${DEVX} -p \$(lsblk -nlpo name,label,partlabel | sed -n '/ESP/ s|.*[sv]da\([0-9]*\).*|\1|p') -l "/EFI/\${ID}/grubx64.efi" -L "\${ID}#${GRP_NM}"
efibootmgr -c -d /dev/${DEVX} -p \$(lsblk -nlpo name,label,partlabel | sed -n '/ESP/ s|.*[sv]da\([0-9]*\).*|\1|p') -l "/EFI/BOOT/BOOTX64.EFI" -L Default
efibootmgr -v ; sleep 3

whois-mkpasswd -m help ; sleep 10

if command -v dnf > /dev/null ; then
  ${DNFCMD} -y clean all
else
  apt-get -y clean ;
fi

exit

EOFchroot

  fstrim -av ; sync
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
