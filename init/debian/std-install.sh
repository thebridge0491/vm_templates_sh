#!/bin/sh -x

# nc -l [-p] {port} > file ## nc -w3 {host} {port} < file  # netcat xfr
# ssh user@ipaddr "su -c 'sh -xs - arg1 argN'" < script.sh
# ssh user@ipaddr "sudo sh -xs - arg1 argN" < script.sh  # w/ sudo

#sh /tmp/disk_setup.sh part_format sgdisk std vg0 pvol0
#sh /tmp/disk_setup.sh mount_filesystems std vg0

# passwd crypted hash: [md5|sha256|sha512] - [$1|$5|$6]$...
# perl -e 'use Term::ReadKey ; print "Password:\n" ; ReadMode "noecho" ; $_=<STDIN> ; ReadMode "normal" ; chomp $_ ; print crypt($_, "\$6\$16CHARACTERSSALT") . "\n"'
# ruby -e "['io/console','digest/sha2'].each {|i| require i} ; puts 'Password:' ; puts STDIN.noecho(&:gets).chomp.crypt(\"\$6\$16CHARACTERSSALT\")"
# python -c "import crypt,getpass ; print(crypt.crypt(getpass.getpass(), \"\$6\$16CHARACTERSSALT\"))"

set -x
if [ -e /dev/vda ] ; then
  export DEVX=vda ;
elif [ -e /dev/sda ] ; then
  export DEVX=sda ;
fi

export GRP_NM=${GRP_NM:-vg0}
# [deb.devuan.org/merged | deb.debian.org/debian]
export MIRROR=${MIRROR:-deb.devuan.org/merged}
if [ "aarch64" = "$(uname -m)" ] ; then
  MACHINE=arm64 ;
elif [ "x86_64" = "$(uname -m)" ] ; then
  MACHINE=amd64 ;
fi
service_mgr=${service_mgr:-sysvinit} # sysvinit | runit | openrc

export INIT_HOSTNAME=${1:-debian-boxv0000}
#export PLAIN_PASSWD=${2:-abcd0123}
export CRYPTED_PASSWD=${2:-\$6\$16CHARACTERSSALT\$o/XwaDmfuxBWVf1nEaH34MYX8YwFlAMo66n1.L3wvwdalv0IaV2b/ajr7xNcX/RFIPvfBNj.2Qxeh7v4JTjJ91}


echo "Create /etc/fstab" ; sleep 3
mkdir -p /mnt/etc /mnt/media ; chmod 0755 /mnt/media
sh -c 'cat > /mnt/etc/fstab' << EOF
PARTLABEL=${GRP_NM}-osRoot   /           auto    errors=remount-ro   0   1
PARTLABEL=${GRP_NM}-osVar    /var        auto    defaults    0   2
PARTLABEL=${GRP_NM}-osHome   /home       auto    defaults    0   2
PARTLABEL=${GRP_NM}-osBoot   /boot       ext2    defaults    0   2
PARTLABEL=ESP      /boot/efi   vfat    umask=0077  0   2
PARTLABEL=${GRP_NM}-osSwap   none        swap    sw          0   0

proc                            /proc       proc    defaults    0   0
sysfs                           /sys        sysfs   defaults    0   0

#9p_Data0           /media/9p_Data0  9p  trans=virtio,version=9p2000.L,rw,_netdev  0  0

#PARTLABEL=data0    /mnt/Data0   exfat   auto,failok,rw,gid=sudo,uid=0   0    0
#PARTLABEL=data0    /mnt/Data0   exfat   auto,failok,rw,dmask=0000,fmask=0111   0    0

EOF


# ip link ; dhclient {ifdev} #; iw dev
# networkctl status ; networkctl up {ifdev}

#ifdev=$(ip -o link | grep 'link/ether' | grep 'LOWER_UP' | sed -n 's|\S*: \(\w*\):.*|\1|p')


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
apt-get --yes update --allow-releaseinfo-change

apt-get --yes install --no-install-recommends makedev
#mount -t proc none /proc
cd /dev ; MAKEDEV generic


echo "Config pkg repo components(main contrib non-free)" ; sleep 3
sed -i 's|VERSION_CODENAME="\(.*\) .*"|VERSION_CODENAME="\1"|' /etc/os-release
. /etc/os-release
sed -i "s| stable| \${VERSION_CODENAME}|" /etc/apt/sources.list
sed -i '/main.*$/ s|main.*$|main contrib non-free|' /etc/apt/sources.list
sed -i '/^#[ ]*deb/ s|^#||' /etc/apt/sources.list
sed -i '/^[ ]*deb cdrom:/ s|^|#|' /etc/apt/sources.list
cat /etc/apt/sources.list ; sleep 5

echo "Add software package selection(s)" ; sleep 3
apt-get --yes update --allow-releaseinfo-change
for pkgX in linux-image-${MACHINE} grub-efi-${MACHINE} efibootmgr grub-pc-bin sudo curl tasksel bsdextrautils linux-headers-${MACHINE} ; do
  apt-get --yes install --no-install-recommends \$pkgX
done
# xfce4
tasksel install standard


echo "Config keyboard ; localization" ; sleep 3
apt-get --yes install --no-install-recommends locales console-setup
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
#echo -n "root:${PLAIN_PASSWD}" | chpasswd
echo -n 'root:${CRYPTED_PASSWD}' | chpasswd -e

DIR_MODE=0750 useradd -m -G operator,sudo -s /bin/bash -c 'Packer User' packer
#echo -n "packer:${PLAIN_PASSWD}" | chpasswd
echo -n 'packer:${CRYPTED_PASSWD}' | chpasswd -e
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
if command -v sv > /dev/null ; then
  ln -s /etc/sv/eudev /etc/service ;
elif command -v rc-update > /dev/null ; then
  rc-update add eudev default ;
elif command -v update-rc.d > /dev/null ; then
  update-rc.d eudev defaults ;
elif command -v systemctl > /dev/null ; then
  systemctl enable udev ;
fi


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
  grub-install --target=i386-pc --recheck /dev/$DEVX ;
  cp -R /boot/efi/EFI/\${ID}/* /boot/efi/EFI/BOOT/ ;
  cp /boot/efi/EFI/BOOT/BOOTX64.EFI /boot/efi/EFI/BOOT/BOOTX64.EFI.bak ;
  cp /boot/efi/EFI/BOOT/grubx64.EFI /boot/efi/EFI/BOOT/BOOTX64.EFI ;
  #cp /boot/efi/EFI/\${ID}/grubx64.efi /boot/efi/EFI/BOOT/BOOTX64.EFI ;
fi

#sed -i -e "s|^GRUB_TIMEOUT=.*$|GRUB_TIMEOUT=1|" /etc/default/grub
#sed -i -e "/GRUB_DEFAULT/ s|=.*$|=saved|" /etc/default/grub
#echo "GRUB_SAVEDEFAULT=true" >> /etc/default/grub
#echo "#GRUB_CMDLINE_LINUX='cryptdevice=/dev/sda2:cryptroot'" >> /etc/default/grub
#echo 'GRUB_PRELOAD_MODULES="lvm"' >> /etc/default/grub
sed -i '/GRUB_CMDLINE_LINUX_DEFAULT/ s|="\(.*\)"|="\1 text xdriver=vesa nomodeset rootdelay=5"|'  \
  /etc/default/grub
if [ "\$(dmesg | grep -ie 'Hypervisor detected')" ] ; then
  sed -i -e '/GRUB_CMDLINE_LINUX_DEFAULT/ s|="\(.*\)"|="\1 net.ifnames=0 biosdevname=0"|' /etc/default/grub ;
fi
grub-mkconfig -o /boot/grub/grub.cfg

if [ "arm64" = "${MACHINE}" ] || [ "aarch64" = "${MACHINE}" ] ; then
  efibootmgr -c -d /dev/$DEVX -p \$(lsblk -nlpo name,label,partlabel | sed -n '/ESP/ s|.*[sv]da\([0-9]*\).*|\1|p') -l "/EFI/\${ID}/grubaa64.efi" -L \${ID}
  efibootmgr -c -d /dev/$DEVX -p \$(lsblk -nlpo name,label,partlabel | sed -n '/ESP/ s|.*[sv]da\([0-9]*\).*|\1|p') -l "/EFI/BOOT/BOOTAA64.EFI" -L Default
else
  efibootmgr -c -d /dev/$DEVX -p \$(lsblk -nlpo name,label,partlabel | sed -n '/ESP/ s|.*[sv]da\([0-9]*\).*|\1|p') -l "/EFI/\${ID}/grubx64.efi" -L \${ID}
  efibootmgr -c -d /dev/$DEVX -p \$(lsblk -nlpo name,label,partlabel | sed -n '/ESP/ s|.*[sv]da\([0-9]*\).*|\1|p') -l "/EFI/BOOT/BOOTX64.EFI" -L Default
fi
efibootmgr -v ; sleep 3


# install/enable ssh just before finish
apt-get --yes install --no-install-recommends openssh-server

apt-get -y clean
fstrim -av
sync

exit

EOFchroot
# end chroot commands

tar -xf /tmp/init.tar -C /mnt/root/ ; sleep 5

read -p "Enter 'y' if ready to unmount & reboot [yN]: " response
if [ "y" = "$response" ] || [ "Y" = "$response" ] ; then
  sync ; swapoff -va ; umount -vR /mnt ;
  reboot ; #poweroff ;
fi
