#!/bin/sh -x

# nc -l [-p] {port} > file ## nc -w3 {host} {port} < file  # netcat xfr
# ssh user@ipaddr "su -c 'sh -xs - arg1 argN'" < script.sh
# ssh user@ipaddr "sudo sh -xs - arg1 argN" < script.sh  # w/ sudo

#sh /tmp/disk_setup.sh part_format sgdisk std vg0 pvol0
#sh /tmp/disk_setup.sh mount_filesystems std vg0

# passwd crypted hash: [md5|sha256|sha512|yescrypt] - [$1|$5|$6|$y$j9T]$...
# stty -echo ; openssl passwd -6 -salt 16CHARACTERSSALT -stdin ; stty echo
# stty -echo ; perl -le 'print STDERR "Password:\n" ; $_=<STDIN> ; chomp $_ ; print crypt($_, "\$6\$16CHARACTERSSALT")' ; stty echo
# ruby -e '["io/console","digest/sha2"].each {|i| require i} ; STDERR.puts "Password:" ; puts STDIN.noecho(&:gets).chomp.crypt("$6$16CHARACTERSSALT")'
# python -c 'import crypt,getpass ; print(crypt.crypt(getpass.getpass(), "$6$16CHARACTERSSALT"))'

set -x
if [ -e /dev/vda ] ; then
  export DEVX=vda ;
elif [ -e /dev/sda ] ; then
  export DEVX=sda ;
fi

export VOL_MGR=${VOL_MGR:-std}
export GRP_NM=${GRP_NM:-vg0} ; export ZPOOLNM=${ZPOOLNM:-ospool0}
# [deb.devuan.org/merged | deb.debian.org/debian]
export MIRROR=${MIRROR:-deb.devuan.org/merged}
if [ "aarch64" = "$(uname -m)" ] ; then
  export MACHINE=arm64 ;
elif [ "x86_64" = "$(uname -m)" ] ; then
  export MACHINE=amd64 ;
fi
export service_mgr=${service_mgr:-sysvinit} # sysvinit | openrc | runit


# ip link ; dhcpcd {ifdev} ; dhclient {ifdev} #; iw dev
# [networkctl status ; networkctl up {ifdev}]

#ntpd -u ntp:ntp ; ntpq -p ; ntpctl -s peers [; timedatectl] ; sleep 3

#ifdev=$(ip -o link | grep 'link/ether' | grep 'LOWER_UP' | sed -n 's|\S*: \(\w*\):.*|\1|p')


export CHROOT_CMD=chroot
#if command -v arch-chroot > /dev/null ; then
#  export CHROOT_CMD=arch-chroot ; # (archlinux: pkg arch-install-scripts)
#elif command -v artix-chroot > /dev/null ; then
#  export CHROOT_CMD=artix-chroot ; # (artix: pkg artools-base)
#elif command -v xchroot > /dev/null ; then
#  export CHROOT_CMD=xchroot ; # (void: pkg xtools[-minimal])
#fi

bootstrap() {
  echo "Bootstrap base pkgs" ; sleep 3
  if command -v debootstrap > /dev/null ; then
    debootstrap --print-debs --no-check-gpg --arch ${MACHINE} --include=makedev ${RELEASE:-stable} /tmp/pkgs_debootstrap http://${MIRROR} | tee /tmp/pkgs_debootstrap.txt ;
    #debootstrap --no-check-gpg --arch ${MACHINE} --variant minbase --include=makedev ${RELEASE:-stable} /mnt file:/cdrom/debian/ ;
    debootstrap --verbose --no-check-gpg --arch ${MACHINE} --include=makedev ${RELEASE:-stable} /mnt http://${MIRROR} ;
  fi
  sleep 5

  cp /etc/mtab /mnt/etc/mtab
  mkdir -p /mnt/proc /mnt/sys /mnt/dev /mnt/run
  if [ "chroot" = "${CHROOT_CMD}" ] ; then
    echo "Prepare chroot (mount --[r]bind devices)" ; sleep 3
    cp /etc/resolv.conf /mnt/etc/resolv.conf

    #mount --rbind /proc /mnt/proc ; mount --rbind /sys /mnt/sys
    #mount --rbind /dev /mnt/dev ; mount --rbind /dev/pts /mnt/dev/pts
    #mount --rbind /run /mnt/run ; mount --rbind /dev/shm /mnt/dev/shm
    for fsX in /proc /sys /dev /dev/pts /run /dev/shm ; do
      mount --rbind ${fsX} /mnt${fsX} ;
    done
  fi
  modprobe efivarfs
  mount -t efivarfs efivarfs /mnt/sys/firmware/efi/efivars/
  sleep 5
  cp /tmp/pkgs_debootstrap.txt /mnt/var/tmp/
}

system_config() {
  export INIT_HOSTNAME=${1:-debian-boxv0000}
  #export PASSWD_PLAIN=${2:-packer}
  export PASSWD_CRYPTED=${2:-\$6\$16CHARACTERSSALT\$A4i3yeafzCxgDj5imBx2ZdMWnr9LGzn3KihP9Dz0zTHbxw31jJGEuuJ6OB6Blkkw0VSUkQzSjE9n4iAAnl0RQ1}

  # LANG=[C|en_US].UTF-8
  cat << EOFchroot | LANG=C.UTF-8 LANGUAGE=en ${CHROOT_CMD} /mnt /bin/sh
set -x

chmod 1777 /tmp ; chmod 1777 /var/tmp

unset LC_ALL
export TERM=xterm-color     # xterm | xterm-color
#hostname ${INIT_HOSTNAME}

ls /proc ; sleep 5 ; ls /dev ; sleep 5

echo "Config pkg repo components(main contrib non-free)" ; sleep 3
sed -i 's|VERSION_CODENAME="\(.*\) .*"|VERSION_CODENAME="\1"|' /etc/os-release
. /etc/os-release
#cp -a /etc/apt/sources.list /etc/apt/sources.list.old
mv /etc/apt/sources.list /etc/apt/sources.list.orig
mkdir -p /etc/apt/sources.list.d
cat << EOF > /etc/apt/sources.list.d/\${VERSION_CODENAME}.list
deb http://${MIRROR} stable main
deb-src http://${MIRROR} stable main

deb http://${MIRROR} stable-security main
deb-src http://${MIRROR} stable-security main

deb http://${MIRROR} stable-updates main
deb-src http://${MIRROR} stable-updates main

deb http://${MIRROR} stable-backports main
deb-src http://${MIRROR} stable-backports main

EOF
sed -i "s| stable| \${VERSION_CODENAME}|g" \
  /etc/apt/sources.list.d/\${VERSION_CODENAME}.list
sed -i '/main.*$/ s|main.*$|main contrib non-free|g' \
  /etc/apt/sources.list.d/\${VERSION_CODENAME}.list
sed -i '/^#[ ]*deb/ s|^#||g' /etc/apt/sources.list.d/\${VERSION_CODENAME}.list
sed -i '/^[ ]*deb cdrom:/ s|^|#|g' /etc/apt/sources.list.d/\${VERSION_CODENAME}.list
cat /etc/apt/sources.list.d/\${VERSION_CODENAME}.list ; sleep 5
apt-get --allow-releaseinfo-change --yes update

#mount -t proc none /proc
cd /dev ; MAKEDEV generic


services_enabled="eudev udev dhcpcd sshd ssh"
pkg_list="apt-utils sudo whois dhcpcd nano curl tasksel bsdextrautils python3-urllib3" # openssh-server xfce4

if [ "devuan" = "\${ID}" ] || [ "debian" = "\${ID}" ] ; then
  if [ "runit" = "${service_mgr}" ] ; then # service_mgr=runit
    pkg_list="\${pkg_list} runit-init" ;
  elif [ "openrc" = "${service_mgr}" ] ; then # service_mgr=openrc
    pkg_list="\${pkg_list} openrc" ;
  elif [ "sysvinit" = "${service_mgr}" ] ; then # service_mgr=sysvinit
    pkg_list="\${pkg_list} sysvinit-core" ;
  fi ;
fi

echo "Add software package selection(s)" ; sleep 3
apt-get --allow-releaseinfo-change --yes update
for pkgX in \${pkg_list} ; do
  apt-get --no-install-recommends --yes install \${pkgX} ;
done
tasksel --new-install install standard


echo "Config keyboard ; localization" ; sleep 3
DEBIAN_FRONTEND=noninteractive apt-get --no-install-recommends --yes install locales console-setup
#dpkg-reconfigure locales ; dpkg-reconfigure keyboard-configuration
kbd_mode -u ; loadkeys us
sed -i '/en_US.UTF-8 UTF-8/ s|^# ||' /etc/locale.gen
echo 'LANG=en_US.UTF-8' >> /etc/locale.conf
locale-gen # en_US en_US.UTF-8

sh -c 'cat >> /etc/default/locale' << EOF
LANG=en_US.UTF-8
#LC_ALL=en_US.UTF-8
LANGUAGE="en_US:en"

EOF


echo "Config time zone & clock" ; sleep 3
#dpkg-reconfigure tzdata
rm /etc/localtime
ln -sf /usr/share/zoneinfo/UTC /etc/localtime
hwclock --systohc --utc


echo "Config hostname ; network" ; sleep 3
echo "${INIT_HOSTNAME}" > /etc/hostname
#sh -c 'cat >> /etc/resolv.conf' << EOF
##search hqdom.local
#nameserver 8.8.8.8
#
#EOF

cat /etc/resolv.conf ; sleep 5
sed -i '/^127.0.1.1/ s|127.0.1.1|#127.0.1.1|' /etc/hosts
echo "127.0.1.1   ${INIT_HOSTNAME}.localdomain  ${INIT_HOSTNAME}" >> /etc/hosts

ifdev=\$(ip -o link | grep 'link/ether' | grep 'LOWER_UP' | sed -n 's|\S*: \(\w*\):.*|\1|p')

mkdir -p /etc/network/interfaces.d #; touch /etc/network/interfaces
#sh -c 'cat >> /etc/network/interfaces' << EOF
#auto lo
#iface lo inet loopback
#
#auto \${ifdev:-eth0}
#allow-hotplug \${ifdev:-eth0}
##iface \${ifdev:-eth0} inet dhcp
##iface \${ifdev:-eth0} inet6 auto
#
##auto wlan0
##iface wlan0 inet dhcp
##  wireless-essid  ????
##  wireless-mode   ????
#
#EOF
#sh -c 'cat >> /etc/network/interfaces.d/ifcfg-lo' << EOF
#auto lo
#iface lo inet loopback
#
#EOF
#sh -c 'cat >> /etc/network/interfaces.d/ifcfg-\${ifdev:-eth0}' << EOF
#auto \${ifdev:-eth0}
#allow-hotplug \${ifdev:-eth0}
##iface \${ifdev:-eth0} inet dhcp
##iface \${ifdev:-eth0} inet6 auto
#
#EOF
#sh -c 'cat >> /etc/network/interfaces.d/ifcfg-wlan0' << EOF
##auto wlan0
##iface wlan0 inet dhcp
##  wireless-essid  ????
##  wireless-mode   ????
#
#EOF
sh -c 'cat > /etc/dhcpcd.conf' << EOF
hostname

clientid

option domain_name_servers,domain_name,domain_search,host_name
option classless_static_routes
option interface_mtu

option ntp_servers

require dhcp_server_identifier

#noarp

EOF

echo "Config services" ; sleep 3

if command -v systemctl > /dev/null ; then # service_mgr=systemd
  cp -a /usr/share/systemd/tmp.mount /etc/systemd/system/ ;
  systemctl enable tmp.mount ; #systemctl enable systemd-machine-id-commit ;
  systemctl stop ssh ;
elif command -v sv > /dev/null ; then # service_mgr=runit
  sv down ssh ;
elif command -v rc-update > /dev/null ; then # service_mgr=openrc
  rc-service sshd stop ;
elif command -v update-rc.d > /dev/null ; then # service_mgr=sysvinit
  echo RAMTMP=yes >> /etc/default/tmpfs ;
  invoke-rc.d ssh stop ; invoke-rc.d sshd stop ;
fi
#echo "tmpfs                           /tmp        tmpfs   defaults,nosuid,nodev,mode=1777   0   0" >> /etc/fstab

echo "Enable services" ; sleep 3
for svc in \${services_enabled} ; do
  if command -v systemctl > /dev/null ; then
    systemctl enable \${svc} ;
  elif command -v sv > /dev/null ; then
    ln -s /etc/sv/\${svc} /etc/service/ ;
  elif command -v rc-update > /dev/null ; then
    rc-update add \${svc} default ;
  elif command -v update-rc.d > /dev/null ; then
    update-rc.d \${svc} defaults ;
  fi ;
done


echo "Set root passwd ; add user" ; sleep 3
#echo -n "root:${PASSWD_PLAIN}" | chpasswd
echo -n 'root:${PASSWD_CRYPTED}' | chpasswd -e

DIR_MODE=0750 useradd -m -G operator,netdev,sudo -s /bin/bash -c 'Packer User' packer
#echo -n "packer:${PASSWD_PLAIN}" | chpasswd
echo -n 'packer:${PASSWD_CRYPTED}' | chpasswd -e
mkdir -m 0700 -p /home/packer/.ssh ; chown -R packer /home/packer

#sh -c 'cat | EDITOR="tee -a" visudo -f /etc/sudoers.d/99_packernopasswd' << EOF
#Defaults:packer !requiretty
#packer ALL=(ALL:ALL) NOPASSWD: ALL
#
#EOF
##chmod 0440 /etc/sudoers.d/99_packernopasswd


sed -i "/^[^#].*requiretty/ s|^|#|" /etc/sudoers
cat << EOF | EDITOR="tee -a" visudo -f /etc/sudoers.d/99_sudonopasswd
#Defaults:%sudo !requiretty
%sudo ALL=(ALL:ALL) NOPASSWD: ALL

EOF


apt-get -y clean

exit

EOFchroot
# end chroot commands
}

kernel_bootloader() {
  # LANG=[C|en_US].UTF-8
  cat << EOFchroot | LANG=C.UTF-8 LANGUAGE=en ${CHROOT_CMD} /mnt /bin/sh
set -x

#sed -i 's|VERSION_CODENAME="\(.*\) .*"|VERSION_CODENAME="\1"|' /etc/os-release
. /etc/os-release

pkg_list="linux-image-${MACHINE} grub-efi-${MACHINE} efibootmgr"

if [ "amd64" = "${MACHINE}" ] ; then
  pkg_list="\${pkg_list} grub-pc-bin" ;
fi

for pkgX in \${pkg_list} ; do
  apt-get --no-install-recommends --yes install \${pkgX} ;
done

if [ ! "\$(dmesg | grep -ie 'Hypervisor detected')" ] ; then
  apt-get --no-install-recommends --yes install firmware-linux-free firmware-linux-nonfree ;
fi

#kver="\$(ls -A /lib/modules/ | tail -1)" # ?? or uname -r
echo \$(uname -r) ; sleep 5

modprobe vfat ; lsmod | grep -e fat ; sleep 5

if [ "zfs" = "${VOL_MGR}" ] ; then
  apt-get --no-install-recommends --yes install dkms linux-headers-${MACHINE} ;
  # spl-dkms dpkg-dev
  DEBIAN_FRONTEND=noninteractive apt-get -t \${VERSION_CODENAME}-backports \
    --yes install zfs-initramfs ;
  # zfs-dkms zfsutils-linux
  mkdir -p /etc/dkms ; echo REMAKE_INITRD=yes > /etc/dkms/zfs.conf ;
  zfs_ver=\$(zfs version | head -n1 | sed 's|zfs-||') ;
  dkms install --verbose zfs/\${zfs_ver} -k \$(uname -r).${UNAME_M} ;
  dkms status ; modprobe zfs ; zfs version ; sleep 5 ;

  zgenhostid -f -o /etc/hostid ; sleep 5 ;

  echo "Hold zfs & kernel package upgrades (require manual upgrade)" ;
  apt-mark hold linux-image-${MACHINE} linux-headers-${MACHINE} \
    linux-image-\$(uname -r) linux-headers-\$(uname -r) \
    zfs-dkms zfsutils-linux zfs-initramfs ;
  #dpkg -l | grep "^hi" ;
  apt-mark showhold ; sleep 3 ;
elif [ "btrfs" = "${VOL_MGR}" ] ; then
  apt-get --no-install-recommends --yes install btrfs-progs ;
  modprobe btrfs ; sleep 5 ;
elif [ "lvm" = "${VOL_MGR}" ] ; then
  apt-get --no-install-recommends --yes install lvm2 ;
  # cryptsetup
  modprobe dm-mod ; vgscan ; vgchange -ay ; lvs ; sleep 5 ;

  for svc in lvm2-lvmpolld lvmetad ; do
    if command -v systemctl > /dev/null ; then
      systemctl enable \${svc} ;
    elif command -v sv > /dev/null ; then
      ln -s /etc/sv/\${svc} /etc/service/ ;
    elif command -v rc-update > /dev/null ; then
      rc-update add \${svc} default ;
    elif command -v update-rc.d > /dev/null ; then
      update-rc.d \${svc} defaults ;
    fi ;
  done ;
fi

update-initramfs -c -k all


grub-probe /boot

echo "Bootloader installation & config" ; sleep 3
mkdir -p /boot/efi/EFI/\${ID} /boot/efi/EFI/BOOT
if [ "arm64" = "${MACHINE}" ] || [ "aarch64" = "${MACHINE}" ] ; then
  grub-install --target=arm64-efi --efi-directory=/boot/efi --bootloader-id=\${ID} --recheck --removable ;
  #cp -R /boot/efi/EFI/\${ID}/* /boot/efi/EFI/BOOT/ ;
  #cp /boot/efi/EFI/BOOT/BOOTAA64.EFI /boot/efi/EFI/BOOT/BOOTAA64.EFI.bak ;
  #cp /boot/efi/EFI/BOOT/grubaa64.EFI /boot/efi/EFI/BOOT/BOOTAA64.EFI ;
  ##cp /boot/efi/EFI/\${ID}/grubaa64.efi /boot/efi/EFI/BOOT/BOOTAA64.EFI ;
else
  grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=\${ID} --recheck --removable ;
  grub-install --target=i386-pc --recheck /dev/${DEVX} ;
  #cp -R /boot/efi/EFI/\${ID}/* /boot/efi/EFI/BOOT/ ;
  #cp /boot/efi/EFI/BOOT/BOOTX64.EFI /boot/efi/EFI/BOOT/BOOTX64.EFI.bak ;
  #cp /boot/efi/EFI/BOOT/grubx64.EFI /boot/efi/EFI/BOOT/BOOTX64.EFI ;
  ##cp /boot/efi/EFI/\${ID}/grubx64.efi /boot/efi/EFI/BOOT/BOOTX64.EFI ;
fi
find / -ipath /boot/efi/*/*.efi ; sleep 5

#sed -ie "s|^GRUB_TIMEOUT=.*$|GRUB_TIMEOUT=1|" /etc/default/grub
#sed -ie "/GRUB_DEFAULT/ s|=.*$|=saved|" /etc/default/grub
#echo "GRUB_SAVEDEFAULT=true" >> /etc/default/grub
#echo "#GRUB_CMDLINE_LINUX='cryptdevice=/dev/sda2:cryptroot'" >> /etc/default/grub
sed -ie '/^GRUB_CMDLINE_LINUX_DEFAULT/ s|^\(.*\)$|#\1\n\1|' /etc/default/grub
sed -ie '/^GRUB_CMDLINE_LINUX_DEFAULT/ s|="\(.*\)"|="\1 xdriver=vesa rootdelay=5 nomodeset text"|'  \
  /etc/default/grub

if [ "zfs" = "${VOL_MGR}" ] ; then
  sed -ie '/^GRUB_CMDLINE_LINUX_DEFAULT/ s| nomodeset| root=ZFS=${ZPOOLNM}/ROOT/default nomodeset|' /etc/default/grub ;
  echo 'GRUB_PRELOAD_MODULES="zfs"' >> /etc/default/grub ;
elif [ "btrfs" = "${VOL_MGR}" ] ; then
  echo 'GRUB_PRELOAD_MODULES="btrfs"' >> /etc/default/grub ;
elif [ "lvm" = "${VOL_MGR}" ] ; then
  echo 'GRUB_PRELOAD_MODULES="lvm"' >> /etc/default/grub ;
fi

if [ "\$(dmesg | grep -ie 'Hypervisor detected')" ] ; then
  sed -ie '/^GRUB_CMDLINE_LINUX_DEFAULT/ s|="\(.*\)"|="\1 net.ifnames=0 biosdevname=0"|' /etc/default/grub ;
fi
grub-mkconfig -o /boot/grub/grub.cfg

if [ "arm64" = "${MACHINE}" ] || [ "aarch64" = "${MACHINE}" ] ; then
  efibootmgr -c -d /dev/${DEVX} -p \$(lsblk -nlpo name,label,partlabel | sed -n '/ESP/ s|.*[sv]da\([0-9]*\).*|\1|p') -l "/EFI/\${ID}/grubaa64.efi" -L "\${ID}#${GRP_NM}"
  efibootmgr -c -d /dev/${DEVX} -p \$(lsblk -nlpo name,label,partlabel | sed -n '/ESP/ s|.*[sv]da\([0-9]*\).*|\1|p') -l "/EFI/BOOT/BOOTAA64.EFI" -L Default
else
  efibootmgr -c -d /dev/${DEVX} -p \$(lsblk -nlpo name,label,partlabel | sed -n '/ESP/ s|.*[sv]da\([0-9]*\).*|\1|p') -l "/EFI/\${ID}/grubx64.efi" -L "\${ID}#${GRP_NM}"
  efibootmgr -c -d /dev/${DEVX} -p \$(lsblk -nlpo name,label,partlabel | sed -n '/ESP/ s|.*[sv]da\([0-9]*\).*|\1|p') -l "/EFI/BOOT/BOOTX64.EFI" -L Default
fi
efibootmgr -v ; sleep 3

mkpasswd -m help ; sleep 10

apt-get --no-install-recommends --yes install openssh-server
if command -v systemctl > /dev/null ; then
  systemctl stop ssh ;
elif command -v sv > /dev/null ; then
  sv down ssh ;
elif command -v rc-update > /dev/null ; then
  rc-service sshd stop ;
elif command -v update-rc.d > /dev/null ; then
  invoke-rc.d sshd stop ; invoke-rc.d ssh stop ;
fi

for svc in eudev udev sshd ssh ; do
  if command -v systemctl > /dev/null ; then
    systemctl enable \${svc} ;
  elif command -v sv > /dev/null ; then
    ln -s /etc/sv/\${svc} /etc/service/ ;
  elif command -v rc-update > /dev/null ; then
    rc-update add \${svc} default ;
  elif command -v update-rc.d > /dev/null ; then
    update-rc.d \${svc} defaults ;
  fi ;
done

apt-get -y clean

exit

EOFchroot

  if [ "zfs" = "${VOL_MGR}" ] ; then
    zpool trim ${ZPOOLNM} ; zpool set autotrim=on ${ZPOOLNM} ;
  else
    fstrim -av ;
  fi
  sync
}

unmount_reboot() {
  read -p "Enter 'y' if ready to unmount & reboot [yN]: " response
  if [ "y" = "${response}" ] || [ "Y" = "${response}" ] ; then
    sync ; swapoff -va ; umount -vR /mnt ;
    if [ "zfs" = "${VOL_MGR}" ] ; then
      #zfs umount -a ; zpool export -a ;
      zfs umount -a ; zpool export ${ZPOOLNM} ;
    fi ;
    reboot ; #poweroff ;
  fi
}

run_install() {
  INIT_HOSTNAME=${1:-}
  #PASSWD_PLAIN=${2:-}
  PASSWD_CRYPTED=${2:-}

  bootstrap
  system_config ${INIT_HOSTNAME} ${PASSWD_CRYPTED}
  kernel_bootloader
  unmount_reboot
}

#----------------------------------------
${@}
