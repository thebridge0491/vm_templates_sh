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

#ifdev=$(ip -o link | grep 'link/ether' | grep 'LOWER_UP' | sed -n 's|\S*: \(\w*\):.*|\1|p')


bootstrap() {
  echo "Bootstrap base pkgs" ; sleep 3
  pkg_list="libgcc ethtool base-voidstrap bash openssh sudo mkpasswd"
  if command -v xbps-install > /dev/null ; then
    if [ "aarch64" = "${UNAME_M}" ] ; then
      yes | XBPS_ARCH=${UNAME_M} xbps-install -Sy -R http://${MIRROR}/current/aarch64 -r /mnt ${pkg_list} ;
    else
      yes | XBPS_ARCH=${UNAME_M} xbps-install -Sy -R http://${MIRROR}/current -r /mnt ${pkg_list} ;
    fi ;
  else
    curl -LO http://${MIRROR}/static/xbps-static-latest.${UNAME_M}-musl.tar.xz ;
    tar -xf xbps-static-latest.${UNAME_M}-musl.tar.xz ;
    if [ "aarch64" = "${UNAME_M}" ] ; then
      yes | XBPS_ARCH=${UNAME_M} ./usr/bin/xbps-install.static -Sy -R http://${MIRROR}/current/aarch64 -r /mnt ${pkg_list} ;
    else
      yes | XBPS_ARCH=${UNAME_M} ./usr/bin/xbps-install.static -Sy -R http://${MIRROR}/current -r /mnt ${pkg_list} ;
    fi ;
  fi

  echo "Prepare chroot (mount --[r]bind devices)" ; sleep 3
  cp /etc/mtab /mnt/etc/mtab
  mkdir -p /mnt/dev /mnt/proc /mnt/sys /mnt/run
  mount --rbind /proc /mnt/proc ; mount --rbind /sys /mnt/sys
  mount --rbind /dev /mnt/dev

  mount --rbind /dev/pts /mnt/dev/pts ; mount --rbind /run /mnt/run
  modprobe efivarfs
  mount -t efivarfs efivarfs /mnt/sys/firmware/efi/efivars/

  cp /etc/resolv.conf /mnt/etc/resolv.conf
  sleep 5
}

system_config() {
  export INIT_HOSTNAME=${1:-void-boxv0000}
  #export PASSWD_PLAIN=${2:-packer}
  export PASSWD_CRYPTED=${2:-\$6\$16CHARACTERSSALT\$A4i3yeafzCxgDj5imBx2ZdMWnr9LGzn3KihP9Dz0zTHbxw31jJGEuuJ6OB6Blkkw0VSUkQzSjE9n4iAAnl0RQ1}

  cat << EOFchroot | LANG=en_US.UTF-8 LANGUAGE=en chroot /mnt /bin/sh
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

echo "Add software package selection(s)" ; sleep 3
yes | xbps-install -Su xbps ; yes | xbps-install -u
for pkgX in void-repo-nonfree python nano wget curl aria2 void-repo-multilib void-repo-multilib-nonfree ; do
  yes | xbps-install -Sy \${pkgX}
done
#yes | xbps-install -Sy xfce4
xbps-query -Rs void-repo-nonfree ; sleep 10

echo "Config keyboard ; localization" ; sleep 3
kbd_mode -u ; loadkeys us
sed -i -e '/en_US.UTF-8 UTF-8/ s|^# ||' /etc/locale.gen
echo 'LANG=en_US.UTF-8' > /etc/locale.conf
echo "en_US.UTF-8 UTF-8" >> /etc/default/libc-locales
xbps-reconfigure -f glibc-locales
locale-gen


echo "Config time zone & clock" ; sleep 3
ln -sf /usr/share/zoneinfo/UTC /etc/localtime
hwclock --systohc --utc


echo "Config hostname ; network" ; sleep 3
echo "${INIT_HOSTNAME}" > /etc/hostname
#resolvconf -u   # generates /etc/resolv.conf
cat /etc/resolv.conf ; sleep 5
sed -i '/127.0.1.1/d' /etc/hosts
echo "127.0.1.1   ${INIT_HOSTNAME}.localdomain  ${INIT_HOSTNAME}" >> /etc/hosts

ifdev=\$(ip -o link | grep 'link/ether' | grep 'LOWER_UP' | sed -n 's|\S*: \(\w*\):.*|\1|p')


echo "Update services" ; sleep 3
ln -s /etc/sv/dhcpcd /etc/runit/runsvdir/default/
ln -s /etc/sv/sshd /etc/runit/runsvdir/default/
sh -c 'cat >> /etc/rc.conf' << EOF
HOSTNAME="${INIT_HOSTNAME}"
HARDWARECLOCK="UTC"
TIMEZONE="Etc/UTC"
KEYMAP="us"

EOF

cat /etc/rc.conf ; sleep 5


echo "Set root passwd ; add user" ; sleep 3
#echo -n "root:${PASSWD_PLAIN}" | chpasswd
echo -n 'root:${PASSWD_CRYPTED}' | chpasswd -e

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


sed -i "/^%wheel.*(ALL)\s*ALL/ s|%wheel|# %wheel|" /etc/sudoers
sed -i "/^#.*%wheel.*NOPASSWD.*/ s|^#.*%wheel|%wheel|" /etc/sudoers
sed -i "s|^[^#].*requiretty|# Defaults requiretty|" /etc/sudoers

xbps-remove -O

exit

EOFchroot
# end chroot commands
}

kernel_bootloader() {
  cat << EOFchroot | LANG=en_US.UTF-8 LANGUAGE=en chroot /mnt /bin/sh
set -x

. /etc/os-release

echo "virtualpkg=linux-headers:linux-lts-headers" >> /etc/xbps.d/99-virtualpkg.conf

if [ "aarch64" = "${UNAME_M}" ] ; then
  yes | xbps-install -Sy linux-lts linux-lts-headers efibootmgr grub-arm64-efi ;
else
  yes | xbps-install -Sy linux-lts linux-lts-headers efibootmgr grub-x86_64-efi ;
fi
modprobe vfat ; lsmod | grep -e fat ; sleep 5


echo "Config dracut"
echo 'hostonly="yes"' >> /etc/dracut.conf

if [ "zfs" = "${VOL_MGR}" ] ; then
  yes | xbps-install -Sy zfs-lts
  mkdir -p /etc/dkms ; echo REMAKE_INITRD=yes > /etc/dkms/zfs.conf
  modprobe zfs ; zfs version ; sleep 5 ;

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
  yes | xbps-install -Sy btrfs-progs ;
  modprobe btrfs ; sleep 5 ;
elif [ "lvm" = "${VOL_MGR}" ] ; then
  yes | xbps-install -Sy lvm2 ;
  # cryptsetup
  modprobe dm-mod ; vgscan ; vgchange -ay ; lvs ; sleep 5 ;
fi

echo "Config Linux kernel"
#xbps-reconfigure -f linux-lts
kernel=\$(xbps-query --regex -s '^linux-lts-[[:digit:]]\.[-0-9\._]*$' | cut -f2 -d' ' | sort -V | tail -n1)
kver="\$(ls -A /lib/modules/ | tail -1)" # ?? or uname -r
#mkinitrd /boot/initrd-\${kver} \${kver}
dracut --kver \${kver} --force
xbps-reconfigure -f \${kernel}


grub-probe /boot

echo "Bootloader installation & config" ; sleep 3
mkdir -p /boot/efi/EFI/\${ID} /boot/efi/EFI/BOOT
if [ "aarch64" = "${UNAME_M}" ] ; then
  grub-install --target=arm64-efi --efi-directory=/boot/efi --bootloader-id=\${ID} --recheck --removable ;
  cp /boot/efi/EFI/\${ID}/grubaa64.efi /boot/efi/EFI/BOOT/BOOTAA64.EFI ;
else
  grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=\${ID} --recheck --removable ;
  grub-install --target=i386-pc --recheck /dev/${DEVX} ;
  cp /boot/efi/EFI/\${ID}/grubx64.efi /boot/efi/EFI/BOOT/BOOTX64.EFI ;
fi

#sed -i -e "s|^GRUB_TIMEOUT=.*$|GRUB_TIMEOUT=1|" /etc/default/grub
sed -i -e '/GRUB_CMDLINE_LINUX_DEFAULT/ s|="\(.*\)"|="\1 rd.auto=1 text xdriver=vesa nomodeset rootdelay=5"|' /etc/default/grub
#sed -i -e '/GRUB_CMDLINE_LINUX_DEFAULT/ s|="\(.*\)"|="\1 video=1024x768 "|' /etc/default/grub

if [ "zfs" = "${VOL_MGR}" ] ; then
  sed -i -e '/GRUB_CMDLINE_LINUX_DEFAULT/ s|nomodeset rootdelay|nomodeset root=ZFS=${ZPOOLNM}/ROOT/default rootdelay|' /etc/default/grub ;
  echo 'GRUB_PRELOAD_MODULES="zfs"' >> /etc/default/grub ;
elif [ "btrfs" = "${VOL_MGR}" ] ; then
  echo 'GRUB_PRELOAD_MODULES="btrfs"' >> /etc/default/grub ;
elif [ "lvm" = "${VOL_MGR}" ] ; then
  echo 'GRUB_PRELOAD_MODULES="lvm"' >> /etc/default/grub ;
fi

if [ "\$(dmesg | grep -ie 'Hypervisor detected')" ] ; then
  sed -i -e '/GRUB_CMDLINE_LINUX_DEFAULT/ s|="\(.*\)"|="\1 net.ifnames=0 biosdevname=0"|' /etc/default/grub ;
fi
grub-mkconfig -o /boot/grub/grub.cfg

if [ "aarch64" = "${UNAME_M}" ] ; then
  efibootmgr -c -d /dev/${DEVX} -p \$(lsblk -nlpo name,label,partlabel | sed -n '/ESP/ s|.*[sv]da\([0-9]*\).*|\1|p') -l "/EFI/\${ID}/grubaa64.efi" -L \${ID}
  efibootmgr -c -d /dev/${DEVX} -p \$(lsblk -nlpo name,label,partlabel | sed -n '/ESP/ s|.*[sv]da\([0-9]*\).*|\1|p') -l "/EFI/BOOT/BOOTAA64.EFI" -L Default
else
  efibootmgr -c -d /dev/${DEVX} -p \$(lsblk -nlpo name,label,partlabel | sed -n '/ESP/ s|.*[sv]da\([0-9]*\).*|\1|p') -l "/EFI/\${ID}/grubx64.efi" -L \${ID}
  efibootmgr -c -d /dev/${DEVX} -p \$(lsblk -nlpo name,label,partlabel | sed -n '/ESP/ s|.*[sv]da\([0-9]*\).*|\1|p') -l "/EFI/BOOT/BOOTX64.EFI" -L Default
fi
efibootmgr -v ; sleep 3

mkpasswd -m help ; sleep 10

exit

EOFchroot

  . /mnt/etc/os-release
  snapshot_name=${ID}_install-$(date -u "+%Y%m%d")

  if [ "zfs" = "${VOL_MGR}" ] ; then
    zfs snapshot ${ZPOOLNM}/ROOT/default@${snapshot_name} ;
    # example remove: zfs destroy ospool0/ROOT/default@snap1
    zfs list -t snapshot ; sleep 5 ;

    zpool trim ${ZPOOLNM} ; zpool set autotrim=on ${ZPOOLNM} ;
  else
    if [ "btrfs" = "${VOL_MGR}" ] ; then
      btrfs subvolume snapshot /mnt /mnt/.snapshots/${snapshot_name} ;
      # example remove: btrfs subvolume delete /.snapshots/snap1
      btrfs subvolume list /mnt ;
    elif [ "lvm" = "${VOL_MGR}" ] ; then
      lvcreate --snapshot --size 2G --name ${snapshot_name} ${GRP_NM}/osRoot ;
      # example remove: lvremove vg0/snap1
      lvs ;
    fi ;
    sleep 5 ; fstrim -av ;
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
