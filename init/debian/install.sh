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
export service_mgr=${service_mgr:-sysvinit} # sysvinit | runit | openrc


# ip link ; dhclient {ifdev} #; iw dev
# networkctl status ; networkctl up {ifdev}

#ifdev=$(ip -o link | grep 'link/ether' | grep 'LOWER_UP' | sed -n 's|\S*: \(\w*\):.*|\1|p')


bootstrap() {
  echo "Bootstrap base pkgs" ; sleep 3
  #debootstrap --no-check-gpg --arch ${MACHINE} --variant minbase ${RELEASE:-stable} /mnt file:/cdrom/debian/
  debootstrap --verbose --no-check-gpg --arch ${MACHINE} ${RELEASE:-stable} /mnt http://${MIRROR}

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
  export INIT_HOSTNAME=${1:-debian-boxv0000}
  #export PASSWD_PLAIN=${2:-packer}
  export PASSWD_CRYPTED=${2:-\$6\$16CHARACTERSSALT\$A4i3yeafzCxgDj5imBx2ZdMWnr9LGzn3KihP9Dz0zTHbxw31jJGEuuJ6OB6Blkkw0VSUkQzSjE9n4iAAnl0RQ1}

  # LANG=[C|en_US].UTF-8
  cat << EOFchroot | LANG=C.UTF-8 LANGUAGE=en chroot /mnt /bin/sh
set -x

chmod 1777 /tmp ; chmod 1777 /var/tmp

unset LC_ALL
export TERM=xterm-color     # xterm | xterm-color
#hostname ${INIT_HOSTNAME}

ls /proc ; sleep 5 ; ls /dev ; sleep 5

cp /etc/apt/sources.list /etc/apt/sources.list.old
cat << EOF > /etc/apt/sources.list
deb http://${MIRROR} stable main
deb-src http://${MIRROR} stable main

deb http://${MIRROR} stable-security main
deb-src http://${MIRROR} stable-security main

deb http://${MIRROR} stable-updates main
deb-src http://${MIRROR} stable-updates main

deb http://${MIRROR} stable-backports main
deb-src http://${MIRROR} stable-backports main

EOF

echo "Config pkg repo components(main contrib non-free)" ; sleep 3
sed -i 's|VERSION_CODENAME="\(.*\) .*"|VERSION_CODENAME="\1"|' /etc/os-release
. /etc/os-release
sed -i "s| stable| \${VERSION_CODENAME}|g" /etc/apt/sources.list
sed -i '/main.*$/ s|main.*$|main contrib non-free|g' /etc/apt/sources.list
sed -i '/^#[ ]*deb/ s|^#||g' /etc/apt/sources.list
sed -i '/^[ ]*deb cdrom:/ s|^|#|g' /etc/apt/sources.list
cat /etc/apt/sources.list ; sleep 5
apt-get --yes update --allow-releaseinfo-change

apt-get --yes install --no-install-recommends makedev
#mount -t proc none /proc
cd /dev ; MAKEDEV generic


echo "Add software package selection(s)" ; sleep 3
apt-get --yes update --allow-releaseinfo-change
for pkgX in sudo whois curl tasksel bsdextrautils ; do
  apt-get --yes install --no-install-recommends \${pkgX} ;
done
# xfce4
tasksel install standard


echo "Config keyboard ; localization" ; sleep 3
DEBIAN_FRONTEND=noninteractive apt-get --yes install --no-install-recommends locales console-setup
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
sed -i '/127.0.1.1/d' /etc/hosts
echo "127.0.1.1    ${INIT_HOSTNAME}.localdomain    ${INIT_HOSTNAME}" >> /etc/hosts

ifdev=\$(ip -o link | grep 'link/ether' | grep 'LOWER_UP' | sed -n 's|\S*: \(\w*\):.*|\1|p')
sh -c 'cat >> /etc/network/interfaces' << EOF
auto lo
iface lo inet loopback

auto \${ifdev}
allow-hotplug \${ifdev}
iface \${ifdev} inet dhcp
iface \${ifdev} inet6 auto

#auto wlan0
#iface wlan0 inet dhcp
#   wireless-essid  ????
#   wireless-mode   ????

EOF


echo "Set root passwd ; add user" ; sleep 3
#echo -n "root:${PASSWD_PLAIN}" | chpasswd
echo -n 'root:${PASSWD_CRYPTED}' | chpasswd -e

DIR_MODE=0750 useradd -m -G operator,sudo -s /bin/bash -c 'Packer User' packer
#echo -n "packer:${PASSWD_PLAIN}" | chpasswd
echo -n 'packer:${PASSWD_CRYPTED}' | chpasswd -e
chown -R packer:\$(id -gn packer) /home/packer

#sh -c 'cat >> /etc/sudoers.d/99_packer' << EOF
#Defaults:packer !requiretty
#\$(id -un packer) ALL=(ALL) NOPASSWD: ALL
#EOF
#chmod 0440 /etc/sudoers.d/99_packer


sed -i "/^%sudo.*(ALL)\s*ALL/ s|%sudo|# %sudo|" /etc/sudoers
#sed -i "/^#.*%sudo.*NOPASSWD.*/ s|^#.*%sudo|%sudo|" /etc/sudoers
echo '%sudo ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers
sed -i "s|^[^#].*requiretty|# Defaults requiretty|" /etc/sudoers


if [ "devuan" = "\${ID}" ] || [ "debian" = "\${ID}" ] ; then
  if [ "sysvinit" = "${service_mgr}" ] ; then
    service_pkgs="sysvinit-core" ;
  elif [ "runit" = "${service_mgr}" ] ; then
    service_pkgs="runit-init" ;
  elif [ "openrc" = "${service_mgr}" ] ; then
    service_pkgs="openrc" ;
  fi ;
  apt-get --yes install --no-install-recommends \${service_pkgs} ;
fi

apt-get --yes install --no-install-recommends openssh-server

if command -v sv > /dev/null ; then
  ln -s /etc/sv/eudev /etc/service ;
  sv down ssh ; ln -s /etc/sv/ssh /etc/service/ ;
elif command -v rc-update > /dev/null ; then
  rc-update add eudev default ;
  rc-service sshd stop ; rc-update add sshd defaults ;
elif command -v update-rc.d > /dev/null ; then
  update-rc.d eudev defaults ;
  invoke-rc.d ssh stop ; update-rc.d ssh defaults ;
  invoke-rc.d sshd stop ; update-rc.d sshd defaults ;
elif command -v systemctl > /dev/null ; then
  systemctl enable udev ;
  systemctl stop ssh ; systemctl enable ssh ;
fi

apt-get -y clean

exit

EOFchroot
# end chroot commands
}

kernel_bootloader() {
  # LANG=[C|en_US].UTF-8
  cat << EOFchroot | LANG=C.UTF-8 LANGUAGE=en chroot /mnt /bin/sh
set -x

#sed -i 's|VERSION_CODENAME="\(.*\) .*"|VERSION_CODENAME="\1"|' /etc/os-release
. /etc/os-release

apt-get --yes install --no-install-recommends linux-image-${MACHINE} linux-headers-${MACHINE} grub-efi-${MACHINE} efibootmgr

if [ "amd64" = "${MACHINE}" ] ; then
  apt-get --yes install --no-install-recommends grub-pc-bin ;
fi
modprobe vfat ; lsmod | grep -e fat ; sleep 5

if [ "zfs" = "${VOL_MGR}" ] ; then
  apt-get --yes install --no-install-recommends dkms ;
  # spl-dkms dpkg-dev
  DEBIAN_FRONTEND=noninteractive apt-get --yes install \
    -t \${VERSION_CODENAME}-backports zfs-initramfs ;
  # zfs-dkms zfsutils-linux
  echo REMAKE_INITRD=yes > /etc/dkms/zfs.conf ;
  modprobe zfs ; zfs version ; sleep 5 ;

  zgenhostid -f -o /etc/hostid ; sleep 5 ;

  echo "Hold zfs & kernel package upgrades (require manual upgrade)" ;
  apt-mark hold linux-image-${MACHINE} linux-headers-${MACHINE} \
    linux-image-\$(uname -r) linux-headers-\$(uname -r) \
    zfs-dkms zfsutils-linux zfs-initramfs ;
  #dpkg -l | grep "^hi" ;
  apt-mark showhold ; sleep 3 ;
elif [ "btrfs" = "${VOL_MGR}" ] ; then
  apt-get --yes install --no-install-recommends btrfs-progs ;
  modprobe btrfs ; sleep 5 ;
elif [ "lvm" = "${VOL_MGR}" ] ; then
  apt-get --yes install --no-install-recommends lvm2 ;
  # cryptsetup
  modprobe dm-mod ; vgscan ; vgchange -ay ; lvs ; sleep 5 ;

  if command -v sv > /dev/null ; then
    ln -s /etc/sv/lvm2-lvmpolld /etc/service ;
  elif command -v rc-update > /dev/null ; then
    rc-update add lvm2-lvmpolld default ;
  elif command -v update-rc.d > /dev/null ; then
    update-rc.d lvm2-lvmpolld defaults ;
  elif command -v systemctl > /dev/null ; then
    systemctl enable lvmetad ; systemctl enable lvm2-lvmpolld ;
  fi ;
fi

update-initramfs -c -k all


grub-probe /boot

echo "Bootloader installation & config" ; sleep 3
mkdir -p /boot/efi/EFI/\${ID} /boot/efi/EFI/BOOT
if [ "arm64" = "${MACHINE}" ] || [ "aarch64" = "${MACHINE}" ] ; then
  grub-install --target=arm64-efi --efi-directory=/boot/efi --bootloader-id=\${ID} --recheck --removable ;
  cp -R /boot/efi/EFI/\${ID}/* /boot/efi/EFI/BOOT/ ;
  cp /boot/efi/EFI/BOOT/BOOTAA64.EFI /boot/efi/EFI/BOOT/BOOTAA64.EFI.bak ;
  cp /boot/efi/EFI/BOOT/grubaa64.EFI /boot/efi/EFI/BOOT/BOOTAA64.EFI ;
  #cp /boot/efi/EFI/\${ID}/grubaa64.efi /boot/efi/EFI/BOOT/BOOTAA64.EFI ;
else
  grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=\${ID} --recheck --removable ;
  grub-install --target=i386-pc --recheck /dev/${DEVX} ;
  cp -R /boot/efi/EFI/\${ID}/* /boot/efi/EFI/BOOT/ ;
  cp /boot/efi/EFI/BOOT/BOOTX64.EFI /boot/efi/EFI/BOOT/BOOTX64.EFI.bak ;
  cp /boot/efi/EFI/BOOT/grubx64.EFI /boot/efi/EFI/BOOT/BOOTX64.EFI ;
  #cp /boot/efi/EFI/\${ID}/grubx64.efi /boot/efi/EFI/BOOT/BOOTX64.EFI ;
fi

#sed -i -e "s|^GRUB_TIMEOUT=.*$|GRUB_TIMEOUT=1|" /etc/default/grub
#sed -i -e "/GRUB_DEFAULT/ s|=.*$|=saved|" /etc/default/grub
#echo "GRUB_SAVEDEFAULT=true" >> /etc/default/grub
#echo "#GRUB_CMDLINE_LINUX='cryptdevice=/dev/sda2:cryptroot'" >> /etc/default/grub
sed -i '/GRUB_CMDLINE_LINUX_DEFAULT/ s|="\(.*\)"|="\1 text xdriver=vesa nomodeset rootdelay=5"|'  \
  /etc/default/grub

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

if [ "arm64" = "${MACHINE}" ] || [ "aarch64" = "${MACHINE}" ] ; then
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
  #snapshot_name=${ID}_${VERSION}-$(date -u "+%Y%m%d")
  snapshot_name=${ID}-${VERSION_ID}_${VERSION_CODENAME}-$(date -u "+%Y%m%d")


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
