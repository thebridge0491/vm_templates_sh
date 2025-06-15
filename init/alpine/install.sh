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
export MIRROR=${MIRROR:-dl-cdn.alpinelinux.org/alpine}
export RELEASE=${RELEASE:-latest-stable}
export UNAME_M=$(uname -m)


# ip link ; dhcpcd eth0 ; udhcpc -i eth0 #; iw dev

#ntpd -u ntp:ntp ; ntpq -p ; ntpctl -s peers ; sleep 3
#rdate -v -a time.nist.gov

#ifdev=$(ip -o link | grep 'link/ether' | grep 'LOWER_UP' | sed -n 's|\S*: \(\w*\):.*|\1|p')


export CHROOT_CMD=chroot
#if command -v arch-chroot > /dev/null ; then
#  export CHROOT_CMD=arch-chroot ; # (archlinux: pkg arch-install-scripts)
#elif command -v artix-chroot > /dev/null ; then
#  export CHROOT_CMD=artix-chroot ; # (artix: pkg artools-base)
#elif command -v xchroot > /dev/null ; then
#  export CHROOT_CMD=xchroot ; # (void: pkg xtools[-minimal])
#fi

_rootfs_extract() {
  tarball_ver=$(curl -Ls http://${MIRROR}/${RELEASE}/releases/${UNAME_M} | sed -n "s|.*alpine-minirootfs-\(.*\)-${UNAME_M}.tar.gz.*|\1|p" | tail -n1)
  curl -Lo /tmp/rootfs.tar.gz \
    http://${MIRROR}/${RELEASE}/releases/${UNAME_M}/alpine-minirootfs-${tarball_ver:-3.20.3}-${UNAME_M}.tar.gz
  curl -Lo /tmp/rootfs.tar.gz.CHECKSUM \
    http://${MIRROR}/${RELEASE}/releases/${UNAME_M}/alpine-minirootfs-${tarball_ver:-3.20.3}-${UNAME_M}.tar.gz.sha256
  cp -a /tmp/rootfs.tar.gz.CHECKSUM /tmp/CHECKSUM
  sha256sum --ignore-missing -c /tmp/CHECKSUM

  #(cat /tmp/rootfs.tar.gz | tar --unlink -xpzf - -C ${DESTDIR:-/mnt})
  (cat /tmp/rootfs.tar.gz | tar -xazf - -C ${DESTDIR:-/mnt})
}

bootstrap() {
  echo "Bootstrap base pkgs" ; sleep 3
  pkg_list="alpine-base tzdata"
  if command -v apk > /dev/null ; then
    apk --arch ${UNAME_M} --repository http://${MIRROR}/${RELEASE}/main --update-cache --allow-untrusted --root /mnt --initdb add ${pkg_list} ;
  else
    if [ ! "1" = "${USE_ROOTFS:-0}" ] ; then
      apktools_ver=$(curl -Ls http://${MIRROR}/${RELEASE}/main/${UNAME_M} | sed -n 's|.*apk-tools-static-\(.*\).apk.*|\1|p') ;
      curl -LO http://${MIRROR}/${RELEASE}/main/${UNAME_M}/apk-tools-static-${apktools_ver:-2.12.10-r1}.apk ;
      tar -xf apk-tools-static-*.apk ;
      ./sbin/apk.static --arch ${UNAME_M} --repository http://${MIRROR}/${RELEASE}/main --update-cache --allow-untrusted --root /mnt --initdb add ${pkg_list} ;
    else
      mv /mnt/etc/fstab /mnt/etc/fstab.disk_setup ;
      _rootfs_extract ;
      cp -a /mnt/etc/fstab /mnt/etc/fstab.rootfs ;
      cp -a /mnt/etc/fstab.disk_setup /mnt/etc/fstab ;
      mv /mnt/etc/resolv.conf /mnt/etc/resolv.conf.rootfs ;
      cp /etc/resolv.conf /mnt/etc/resolv.conf ; cp /etc/mtab /mnt/etc/mtab ;
      # LANG=[C|en_US].UTF-8
      cat << EOFchroot | LANG=C.UTF-8 LANGUAGE=en ${CHROOT_CMD} /mnt /bin/sh ;
set -x

unalias -a

RELEASE=\$(cat /etc/alpine-release | cut -d. -f1-2)
sed -i '/cdrom/ s|^|#|' /etc/apk/repositories
echo "http://${MIRROR}/v\${RELEASE}/main" >> /etc/apk/repositories
echo "http://${MIRROR}/v\${RELEASE}/community" >> /etc/apk/repositories
apk --arch ${UNAME_M} update
apk --repository http://${MIRROR}/\${RELEASE}/main --update-cache --allow-untrusted --initdb add ${pkg_list}
cat /etc/apk/repositories

exit

EOFchroot
    fi ;
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
  mkdir -p /mnt/root /mnt/etc/apk ; cp -a /etc/apk/repositories /mnt/etc/apk/
  sleep 5
}

system_config() {
  export INIT_HOSTNAME=${1:-alpine-boxv0000}
  #export PASSWD_PLAIN=${2:-packer}
  export PASSWD_CRYPTED=${2:-\$6\$16CHARACTERSSALT\$A4i3yeafzCxgDj5imBx2ZdMWnr9LGzn3KihP9Dz0zTHbxw31jJGEuuJ6OB6Blkkw0VSUkQzSjE9n4iAAnl0RQ1}

  cat << EOFchroot | LANG=en_US.UTF-8 LANGUAGE=en ${CHROOT_CMD} /mnt /bin/sh
set -x

chmod 1777 /tmp ; chmod 1777 /var/tmp
chown root:root / ; chmod 0755 /

unset LC_ALL
export TERM=xterm-color     # xterm | xterm-color
#hostname ${INIT_HOSTNAME}

ls /proc ; sleep 5 ; ls /dev ; sleep 5

. /etc/os-release
RELEASE=\$(cat /etc/alpine-release | cut -d. -f1-2)
sed -i '/cdrom/ s|^|#|' /etc/apk/repositories
echo "http://${MIRROR}/v\${RELEASE}/main" >> /etc/apk/repositories
echo "http://${MIRROR}/v\${RELEASE}/community" >> /etc/apk/repositories
apk --arch ${UNAME_M} update
cat /etc/apk/repositories ; sleep 5


services_enabled="udev udev-trigger udev-settle udev-postmount networking urandom hostname hwclock modules sysctl bootmisc swap loadkmap mount-ro killprocs savecache devfs dmesg mdev hwdrivers acpid dhcpcd sshd"
services_disabled="syslog crond"
pkg_list="eudev eudev-openrc udev-init-scripts lsb-release-minimal man-db man-pages dhcpcd bash sudo mkpasswd util-linux util-linux-misc coreutils iproute2-ss musl-locales pciutils shadow openssh python3 py3-urllib3"
# xfce4

echo "Add software package selection(s)" ; sleep 3
for pkgX in \${pkg_list} ; do
  apk --arch ${UNAME_M} add \${pkgX} ;
done
sleep 5


echo "Config keyboard ; localization" ; sleep 3
kbd_mode -u ; loadkeys us
sed -i -e '/en_US.UTF-8 UTF-8/ s|^# ||' /etc/locale.gen
echo 'LANG=en_US.UTF-8' > /etc/locale.conf
echo "en_US.UTF-8 UTF-8" >> /etc/default/libc-locales
locale-gen


echo "Config time zone & clock" ; sleep 3
ln -sf /usr/share/zoneinfo/UTC /etc/localtime
hwclock --systohc --utc


echo "Config hostname ; network" ; sleep 3
echo "${INIT_HOSTNAME}" > /etc/hostname
#resolvconf -u   # generates /etc/resolv.conf
cat /etc/resolv.conf ; sleep 5
sed -i '/^127.0.1.1/ s|127.0.1.1|#127.0.1.1|' /etc/hosts
echo "127.0.1.1   ${INIT_HOSTNAME}.localdomain  ${INIT_HOSTNAME}" >> /etc/hosts

ifdev=\$(ip -o link | grep 'link/ether' | grep 'LOWER_UP' | sed -n 's|\S*: \(\w*\):.*|\1|p')

mkdir -p /etc/network/interfaces.d ; touch /etc/network/interfaces
#sh -c 'cat > /etc/network/interfaces' << EOF
#auto lo
#iface lo inet loopback
#
#auto \${ifdev:-eth0}
##iface \${ifdev:-eth0} inet dhcp
#
#EOF
sh -c 'cat > /etc/network/interfaces.d/ifcfg-lo' << EOF
auto lo
iface lo inet loopback

EOF
sh -c 'cat > /etc/network/interfaces.d/ifcfg-\${ifdev:-eth0}' << EOF
auto \${ifdev:-eth0}
#iface \${ifdev:-eth0} inet dhcp

EOF


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
useradd -m -g users -G wheel,netdev -s /bin/bash -c 'Packer User' packer
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


#sed -i "/^[^#].*requiretty/ s|^|#|" /etc/sudoers
cat << EOF | EDITOR="tee -a" visudo -f /etc/sudoers.d/99_wheelnopasswd
#Defaults:%wheel !requiretty
%wheel ALL=(ALL:ALL) NOPASSWD: ALL

EOF

#echo "Temporarily permit root login via ssh password" ; sleep 3
#sed -i "/PermitRootLogin/ s|^\(.*\)$|PermitRootLogin yes|" /etc/ssh/sshd_config
#sed -i "s|.*PermitRootLogin|#PermitRootLogin|" /etc/ssh/sshd_config
#echo "PermitRootLogin yes" > /etc/ssh/sshd_config.d/99-rootlogin.conf

apk --arch ${UNAME_M} -v cache clean

exit

EOFchroot
# end chroot commands
}

kernel_bootloader() {
  cat << EOFchroot | LANG=en_US.UTF-8 LANGUAGE=en ${CHROOT_CMD} /mnt /bin/sh
set -x

. /etc/os-release

services_enabled=""
pkg_list="linux-lts mkinitfs grub-efi efibootmgr" # xfce4
if [ "x86_64" = "${UNAME_M}" ] ; then
  pkg_list="\${pkg_list} grub-bios" ;
fi
if [ "\$(dmesg | grep -ie 'Hypervisor detected')" ] ; then
  pkg_list="linux-firmware-none \${pkg_list}" ;
fi

for pkgX in \${pkg_list} ; do
  apk --arch ${UNAME_M} add \${pkgX} ;
done

kver="\$(ls -A /lib/modules/ | tail -1)"
echo \${kver} ; sleep 5

modprobe vfat ; lsmod | grep -e fat ; sleep 5

if [ "zfs" = "${VOL_MGR}" ] ; then
  apk --arch ${UNAME_M} add linux-lts-dev akms zfs zfs-scripts ;
  zfs_ver=\$(zfs version | head -n1 | sed 's|zfs-||') ;
  akms install --verbose zfs/\${zfs_ver} -k \${kver}.${UNAME_M} ;
  akms status ; modprobe zfs ; zfs version ; sleep 5 ;

  zgenhostid -f -o /etc/hostid ; sleep 5 ;

  services_enabled="\${services_enabled} zfs-import zfs-mount" ;
  features="ata base cdrom ext4 xfs keymap kms mmc raid scsi usb virtio zfs network" ;

  #echo "Hold zfs & kernel package upgrades (require manual upgrade)" ;
  apk --arch ${UNAME_M} fix ; sleep 3 ;
  if [ "\$(dmesg | grep -ie 'Hypervisor detected')" ] ; then
    apk --arch ${UNAME_M} add linux-firmware-none=\$(apk --arch ${UNAME_M} info -ve linux-firmware-none | sed "s|linux-firmware-none-\(.*\)|\1|") ;
  fi ;
  for pkgX in linux-lts linux-lts-dev zfs zfs-lts zfs-openrc ; do
    apk --arch ${UNAME_M} add \${pkgX}=\$(apk --arch ${UNAME_M} info -ve \${pkgX} | sed "s|\${pkgX}-\(.*\)|\1|") ;
  done ;
  # ?? how to display held/pinned packages ??
elif [ "btrfs" = "${VOL_MGR}" ] ; then
  apk --arch ${UNAME_M} add btrfs-progs ;
  modprobe btrfs ; sleep 5 ;

  cat << EOF >> /etc/init.d/btrfs-scan ;
#!/sbin/openrc-run

name="btrfs-scan"

depend() {
  before localmount
}

start() {
  /sbin/btrfs device scan
}

EOF
  chmod +x /etc/init.d/btrfs-scan ;

  services_enabled="\${services_enabled} btrfs-scan" ;
  features="ata base cdrom ext4 xfs keymap kms mmc raid scsi usb virtio btrfs network" ;
elif [ "lvm" = "${VOL_MGR}" ] ; then
  apk --arch ${UNAME_M} add lvm2 ;
  # cryptsetup
  modprobe dm-mod ; vgscan ; vgchange -ay ; lvs ; sleep 5 ;

  services_enabled="\${services_enabled} lvm" ;
  features="ata base cdrom ext4 xfs keymap kms mmc raid scsi usb virtio lvm network" ;
else
  features="ata base cdrom ext4 xfs keymap kms mmc raid scsi usb virtio network" ;
fi

boot_svcs="networking urandom hostname hwclock modules sysctl bootmisc swap loadkmap syslog rsyslog lvm btrfs-scan"
shutdown_svcs="mount-ro killprocs savecache"
sysinit_svcs="devfs dmesg mdev hwdrivers udev udev-trigger zfs-import zfs-mount"
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

echo "Config Linux kernel"
echo features=\""\${features}"\" > /etc/mkinitfs/mkinitfs.conf

mkinitfs "\${kver}"


grub-probe /boot

echo "Bootloader installation & config" ; sleep 3
mkdir -p /boot/efi/EFI/\${ID} /boot/efi/EFI/BOOT
if [ "aarch64" = "${UNAME_M}" ] ; then
  grub-install --target=arm64-efi --efi-directory=/boot/efi --bootloader-id=\${ID} --recheck --removable ;
  #cp /boot/efi/EFI/\${ID}/grubaa64.efi /boot/efi/EFI/BOOT/BOOTAA64.EFI ;
else
  grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=\${ID} --recheck --removable ;
  grub-install --target=i386-pc --recheck /dev/${DEVX} ;
  #cp /boot/efi/EFI/\${ID}/grubx64.efi /boot/efi/EFI/BOOT/BOOTX64.EFI ;
fi
find / -ipath /boot/efi/*/*.efi ; sleep 5

#sed -ie "s|^GRUB_TIMEOUT=.*$|GRUB_TIMEOUT=1|" /etc/default/grub
if [ -z "\$(grep GRUB_CMDLINE_LINUX_DEFAULT /etc/default/grub)" ] ; then
  echo '#GRUB_CMDLINE_LINUX_DEFAULT="rd.auto=1 rootdelay=5 modules=sd-mod,usb-storage,ext4 nomodeset text"' >> /etc/default/grub ;
  echo 'GRUB_CMDLINE_LINUX_DEFAULT="rd.auto=1 rootdelay=5 modules=sd-mod,usb-storage,ext4 nomodeset text"' >> /etc/default/grub ;
else
  sed -ie '/^GRUB_CMDLINE_LINUX_DEFAULT/ s|^\(.*\)$|#\1\n\1|' /etc/default/grub
  #sed -ie '/^GRUB_CMDLINE_LINUX_DEFAULT/ s|="\(.*\)"|="\1 rd.auto=1 xdriver=vesa rootdelay=5 modules=sd-mod,usb-storage,ext4 nomodeset text"|' /etc/default/grub ;
fi
#sed -ie '/^GRUB_CMDLINE_LINUX_DEFAULT/ s|="\(.*\)"|="\1 video=1024x768 "|' /etc/default/grub

if [ "zfs" = "${VOL_MGR}" ] ; then
  sed -ie '/^GRUB_CMDLINE_LINUX_DEFAULT/ s|\(usb-storage,ext4\)|\1,zfs|' /etc/default/grub ;
  sed -ie '/^GRUB_CMDLINE_LINUX_DEFAULT/ s| nomodeset| root=ZFS=${ZPOOLNM}/ROOT/default nomodeset|' /etc/default/grub ;
  echo 'GRUB_PRELOAD_MODULES="zfs"' >> /etc/default/grub ;
elif [ "btrfs" = "${VOL_MGR}" ] ; then
  sed -ie '/^GRUB_CMDLINE_LINUX_DEFAULT/ s|\(usb-storage,ext4\)|\1,btrfs|' /etc/default/grub ;
  echo 'GRUB_PRELOAD_MODULES="btrfs"' >> /etc/default/grub ;
elif [ "lvm" = "${VOL_MGR}" ] ; then
  sed -ie '/^GRUB_CMDLINE_LINUX_DEFAULT/ s|\(usb-storage,ext4\)|\1,lvm|' /etc/default/grub ;
  echo 'GRUB_PRELOAD_MODULES="lvm"' >> /etc/default/grub ;
fi

if [ "\$(dmesg | grep -ie 'Hypervisor detected')" ] ; then
  sed -ie '/^GRUB_CMDLINE_LINUX_DEFAULT/ s|="\(.*\)"|="\1 net.ifnames=0 biosdevname=0"|' /etc/default/grub ;
fi
grub-mkconfig -o /boot/grub/grub.cfg

if [ "aarch64" = "${UNAME_M}" ] ; then
  efibootmgr -c -d /dev/${DEVX} -p \$(lsblk -nlpo name,label,partlabel | sed -n '/ESP/ s|.*[sv]da\([0-9]*\).*|\1|p') -l "/EFI/\${ID}/grubaa64.efi" -L "\${ID}#${GRP_NM}"
  efibootmgr -c -d /dev/${DEVX} -p \$(lsblk -nlpo name,label,partlabel | sed -n '/ESP/ s|.*[sv]da\([0-9]*\).*|\1|p') -l "/EFI/BOOT/BOOTAA64.EFI" -L Default
else
  efibootmgr -c -d /dev/${DEVX} -p \$(lsblk -nlpo name,label,partlabel | sed -n '/ESP/ s|.*[sv]da\([0-9]*\).*|\1|p') -l "/EFI/\${ID}/grubx64.efi" -L "\${ID}#${GRP_NM}"
  efibootmgr -c -d /dev/${DEVX} -p \$(lsblk -nlpo name,label,partlabel | sed -n '/ESP/ s|.*[sv]da\([0-9]*\).*|\1|p') -l "/EFI/BOOT/BOOTX64.EFI" -L Default
fi
efibootmgr -v ; sleep 3

mkpasswd -m help ; sleep 10

apk --arch ${UNAME_M} -v cache clean

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
