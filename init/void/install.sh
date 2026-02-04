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
# (x86_64) repo-default.voidlinux.org/current
# (aarch64) repo-default.voidlinux.org/current/aarch64
export MIRROR=${MIRROR:-repo-default.voidlinux.org}
export UNAME_M=$(uname -m)


# ip link ; dhcpcd {ifdev}

#ntpd -u ntp:ntp ; ntpq -p ; ntpctl -s peers ; sleep 3

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
  tarball_ver=$(curl -Ls http://${MIRROR}/live/current | sed -n 's|.*void-${UNAME_M}-ROOTFS-\(.*\).tar.xz.*|\1|p' | tail -n1)
  curl -Lo /tmp/rootfs.tar.xz \
    http://${MIRROR}/live/current/void-${UNAME_M}-ROOTFS-${tarball_ver:-20250202}.tar.xz
  curl -Lo /tmp/rootfs.tar.xz.CHECKSUM \
    http://${MIRROR}/live/current/sha256sum.txt
  grep "void-${UNAME_M}-ROOTFS" /tmp/rootfs.tar.xz.CHECKSUM | grep '^SHA256' \
    | sed -E 's|.*= ([a-z0-9]*)$|\1  rootfs.tar.xz|' > /tmp/CHECKSUM
  #cp -a /tmp/rootfs.tar.xz.CHECKSUM /tmp/CHECKSUM
  sha256sum --ignore-missing -c /tmp/CHECKSUM

  #(cat /tmp/rootfs.tar.xz | tar --unlink -xpJf - -C ${DESTDIR:-/mnt})
  (cat /tmp/rootfs.tar.xz | tar -xaJf - -C ${DESTDIR:-/mnt})
}

bootstrap() {
  echo "Bootstrap base pkgs" ; sleep 3
  pkg_list="libgcc ethtool base-container-full mkpasswd"
  if [ ! "1" = "${USE_ROOTFS:-1}" ] && command -v xbps-install > /dev/null ; then
    if [ "aarch64" = "${UNAME_M}" ] ; then
      yes | XBPS_ARCH=${UNAME_M} xbps-install -R http://${MIRROR}/current/aarch64 -r /mnt -Sy ${pkg_list} ;
    else
      yes | XBPS_ARCH=${UNAME_M} xbps-install -R http://${MIRROR}/current -r /mnt -Sy ${pkg_list} ;
    fi ;
  else
    if [ ! "1" = "${USE_ROOTFS:-1}" ] ; then
      curl -LO http://${MIRROR}/static/xbps-static-latest.${UNAME_M}-musl.tar.xz ;
      tar -xf xbps-static-latest.${UNAME_M}-musl.tar.xz ;
      if [ "aarch64" = "${UNAME_M}" ] ; then
        yes | XBPS_ARCH=${UNAME_M} SSL_NO_VERIFY_PEER=1 ./usr/bin/xbps-install.static -R http://${MIRROR}/current/aarch64 -r /mnt -Sy ${pkg_list} ;
      else
        yes | XBPS_ARCH=${UNAME_M} SSL_NO_VERIFY_PEER=1 ./usr/bin/xbps-install.static -R http://${MIRROR}/current -r /mnt -Sy ${pkg_list} ;
      fi ;
    else
      mv /mnt/etc/fstab /mnt/etc/fstab.disk_setup ;
      _rootfs_extract ;
      cp -a /mnt/etc/fstab /mnt/etc/fstab.rootfs ;
      mv /mnt/etc/fstab.disk_setup /mnt/etc/fstab ;
      mv /mnt/etc/resolv.conf /mnt/etc/resolv.conf.rootfs ;
      cp /etc/resolv.conf /mnt/etc/resolv.conf ; cp /etc/mtab /mnt/etc/mtab ;
      # LANG=[C|en_US].UTF-8
      cat << EOFchroot | LANG=C.UTF-8 LANGUAGE=en ${CHROOT_CMD} /mnt /bin/sh ;
set -x

unalias -a

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
  sleep 5
}

system_config() {
  export INIT_HOSTNAME=${1:-void-boxv0000}
  #export PASSWD_PLAIN=${2:-packer}
  export PASSWD_CRYPTED=${2:-\$6\$16CHARACTERSSALT\$A4i3yeafzCxgDj5imBx2ZdMWnr9LGzn3KihP9Dz0zTHbxw31jJGEuuJ6OB6Blkkw0VSUkQzSjE9n4iAAnl0RQ1}

  cat << EOFchroot | LANG=en_US.UTF-8 LANGUAGE=en ${CHROOT_CMD} /mnt /bin/sh
set -x

chmod 1777 /tmp ; chmod 1777 /var/tmp
chown root:root /

unset LC_ALL
export TERM=xterm-color     # xterm | xterm-color
#hostname ${INIT_HOSTNAME}

ls /proc ; sleep 5 ; ls /dev ; sleep 5

. /etc/os-release ; mkdir -p /etc/xbps.d
if [ "aarch64" = "${UNAME_M}" ] ; then
  echo "repository=https://${MIRROR}/current/aarch64" >> /etc/xbps.d/00-repository-main.conf
else
  echo "repository=https://${MIRROR}/current" >> /etc/xbps.d/00-repository-main.conf
fi
xbps-install -S ; xbps-query -L ; sleep 5

services_enabled="dhcpcd sshd"
pkg_list="void-repo-nonfree nano wget curl aria2 void-repo-multilib void-repo-multilib-nonfree mkpasswd python3 python3-urllib3"
# xfce4

# if socklog[-void] installed, remove
test -e /var/log/socklog && rm -fr /var/log/socklog
xbps-remove -y socklog socklog-void

echo "Add software package selection(s)" ; sleep 3
yes | xbps-install -Su xbps ; yes | xbps-install -u
for pkgX in \${pkg_list} ; do
  yes | xbps-install -y \${pkgX} ;
done
xbps-query -Rs void-repo-nonfree ; sleep 10

echo "Config keyboard ; localization" ; sleep 3
kbd_mode -u ; loadkeys us
sed -ie '/en_US.UTF-8 UTF-8/ s|^# ||' /etc/locale.gen # ??
echo 'LANG=en_US.UTF-8' > /etc/locale.conf
echo "en_US.UTF-8 UTF-8" >> /etc/default/libc-locales
xbps-reconfigure -f glibc-locales
locale-gen # ??


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


sh -c 'cat >> /etc/rc.conf' << EOF
#HOSTNAME="${INIT_HOSTNAME}"
HARDWARECLOCK="UTC"
TIMEZONE="Etc/UTC"
KEYMAP="us"

EOF

cat /etc/rc.conf ; sleep 5

echo "Config services" ; sleep 3

echo "Enable|disable services" ; sleep 3
for svc in \${services_enabled} ; do
  ln -s /etc/sv/\${svc} /etc/runit/runsvdir/default/ ;
done
for svc in nanoklogd socklog-unix ; do
  rm /etc/runit/runsvdir/default/\${svc} ;
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


#sed -i '/^[^#].*requiretty/ s|^|#|' /etc/sudoers
cat << EOF | EDITOR="tee -a" visudo -f /etc/sudoers.d/99_wheelnopasswd
#Defaults:%wheel !requiretty
%wheel ALL=(ALL:ALL) NOPASSWD: ALL

EOF

xbps-remove -Oy

exit

EOFchroot
# end chroot commands
}

kernel_bootloader() {
  cat << EOFchroot | LANG=en_US.UTF-8 LANGUAGE=en ${CHROOT_CMD} /mnt /bin/sh
set -x

. /etc/os-release

echo "virtualpkg=linux-headers:linux-lts-headers" >> /etc/xbps.d/99-virtualpkg.conf

pkg_list="linux-lts efibootmgr"

if [ "aarch64" = "${UNAME_M}" ] ; then
  pkg_list="\${pkg_list} grub-arm64-efi" ;
else
  pkg_list="\${pkg_list} grub-x86_64-efi" ;
fi

if [ "\$(dmesg | grep -iE 'kvm|qemu|hypervisor')" ] ; then
  for pkgX in linux-firmware-amd linux-firmware-intel linux-firmware-network linux-firmware-nvidia ; do
    echo "ignorepkg=\${pkgX}" >> /etc/xbps.d/99-ignorefirmware.conf ;
    yes | xbps-remove -y \${pkgX} ;
  done ;
fi

yes | xbps-install -Sy \${pkg_list}

kver="\$(ls -A /usr/lib/modules/ | tail -1)" # ?? or uname -r
echo \${kver} ; sleep 5

modprobe vfat ; lsmod | grep -e fat ; sleep 5


echo "Config dracut"
echo 'hostonly="yes"' >> /etc/dracut.conf

if [ "zfs" = "${VOL_MGR}" ] ; then
  yes | xbps-install -y linux-lts-headers dkms zfs-lts
  mkdir -p /etc/dkms ; echo REMAKE_INITRD=yes > /etc/dkms/zfs.conf ;
  zfs_ver=\$(zfs version | head -n1 | sed 's|zfs-||') ;
  dkms install --verbose zfs/\${zfs_ver} -k \${kver}.${UNAME_M} ;
  dkms status ; modprobe zfs ; zfs version ; sleep 5 ;

  zgenhostid -f -o /etc/hostid ; sleep 5 ;

  mkdir -p /etc/dracut.conf.d ;
  echo 'nofsck="yes"' >> /etc/dracut.conf.d/zol.conf ;
  echo 'add_dracutmodules+=" zfs "' >> /etc/dracut.conf.d/zol.conf ;
  echo 'omit_dracutmodules+=" btrfs resume "' >> /etc/dracut.conf.d/zol.conf ;

  echo "Hold zfs & kernel package upgrades (require manual upgrade)" ;
  linuxver=\$(xbps-query -Rx linux-lts | sed -n '/linux[0-9.]/ s|\(linux[0-9.]*\).*|\1|p') ;
  xbps-pkgdb -m hold zfs-lts linux-lts linux-lts-headers \${linuxver} \${linuxver}-headers ;
  xbps-query --list-hold-pkgs ; sleep 3 ;
elif [ "btrfs" = "${VOL_MGR}" ] ; then
  yes | xbps-install -y btrfs-progs ;
  modprobe btrfs ; sleep 5 ;
elif [ "lvm" = "${VOL_MGR}" ] ; then
  yes | xbps-install -y lvm2 ;
  # cryptsetup
  modprobe dm-mod ; vgscan ; vgchange -ay ; lvs ; sleep 5 ;
fi

echo "Config Linux kernel"
#xbps-reconfigure -f linux-lts
kernel=\$(xbps-query --regex -s '^linux-lts-[[:digit:]]\.[-0-9\._]*$' | cut -f2 -d' ' | sort -V | tail -n1)

#mkinitrd /boot/initrd-\${kver}.img \${kver}
dracut --force --kver \${kver}
xbps-reconfigure -f \${kernel}


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

#sed -ie 's|^GRUB_TIMEOUT=.*$|GRUB_TIMEOUT=1|' /etc/default/grub
sed -ie '/^GRUB_CMDLINE_LINUX_DEFAULT/ s|^\(.*\)$|#\1\n\1|' /etc/default/grub
sed -ie '/^GRUB_CMDLINE_LINUX_DEFAULT/ s|="\(.*\)"|="\1 rd.auto=1 xdriver=vesa rootdelay=5 nomodeset text"|' /etc/default/grub
#sed -ie '/^GRUB_CMDLINE_LINUX_DEFAULT/ s|="\(.*\)"|="\1 video=1024x768 "|' /etc/default/grub

if [ "zfs" = "${VOL_MGR}" ] ; then
  sed -ie '/^GRUB_CMDLINE_LINUX_DEFAULT/ s| nomodeset| root=ZFS=${ZPOOLNM}/ROOT/default nomodeset|' /etc/default/grub ;
  echo 'GRUB_PRELOAD_MODULES="zfs"' >> /etc/default/grub ;
elif [ "btrfs" = "${VOL_MGR}" ] ; then
  echo 'GRUB_PRELOAD_MODULES="btrfs"' >> /etc/default/grub ;
elif [ "lvm" = "${VOL_MGR}" ] ; then
  echo 'GRUB_PRELOAD_MODULES="lvm"' >> /etc/default/grub ;
fi

if [ "\$(dmesg | grep -iE 'kvm|qemu|hypervisor')" ] ; then
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

xbps-remove -Ooy

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
  export INIT_HOSTNAME=${1:-}
  #export PASSWD_PLAIN=${2:-}
  export PASSWD_CRYPTED=${2:-}

  bootstrap
  system_config ${INIT_HOSTNAME} ${PASSWD_CRYPTED}
  kernel_bootloader
  unmount_reboot
}

#----------------------------------------
${@}
