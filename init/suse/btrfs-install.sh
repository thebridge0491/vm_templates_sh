#!/bin/bash -x

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

export GRP_NM=${GRP_NM:-vg0}
export MIRROR=${MIRROR:-download.opensuse.org} ; UNAME_M=$(uname -m)
RELEASE=${RELEASE:-openSUSE-current}

export INIT_HOSTNAME=${1:-suse-boxv0000}
#export PASSWD_PLAIN=${2:-packer}
export PASSWD_CRYPTED=${2:-\$6\$16CHARACTERSSALT\$A4i3yeafzCxgDj5imBx2ZdMWnr9LGzn3KihP9Dz0zTHbxw31jJGEuuJ6OB6Blkkw0VSUkQzSjE9n4iAAnl0RQ1}


echo "Create /etc/fstab" ; sleep 3
mkdir -p /mnt/etc /mnt/media ; chmod 0755 /mnt/media
sh -c 'cat > /mnt/etc/fstab' << EOF
PARTLABEL=${PV_NM:-pvol0}  /          auto    noatime,compress=lzo,subvol=/@   0   0
PARTLABEL=${GRP_NM}-osBoot   /boot       ext2    defaults    0   2
PARTLABEL=ESP      /boot/efi   vfat    umask=0077  0   2
PARTLABEL=${GRP_NM}-osSwap   none        swap    sw          0   0

PARTLABEL=${PV_NM:-pvol0}  /.snapshots  auto    noatime,compress=lzo,subvol=/@/.snapshots   0   0
PARTLABEL=${PV_NM:-pvol0}  /var  auto    noatime,compress=lzo,subvol=/@/var   0   0
PARTLABEL=${PV_NM:-pvol0}  /tmp  auto    noatime,compress=lzo,subvol=/@/tmp   0   0
PARTLABEL=${PV_NM:-pvol0}  /home  auto    noatime,compress=lzo,subvol=/@/home   0   0

proc                            /proc       proc    defaults    0   0
sysfs                           /sys        sysfs   defaults    0   0

#9p_Data0           /media/9p_Data0  9p  trans=virtio,version=9p2000.L,rw,_netdev  0  0

EOF


# ifconfig [;ifconfig wlan create wlandev ath0 ; ifconfig wlan0 up scan]
# networkctl status ; networkctl up {ifdev}
# nmcli device status ; nmcli connection up {ifdev}
# wicked ifstatus all ; wicked up {ifdev}

#ifdev=$(ip -o link | grep 'link/ether' | grep 'LOWER_UP' | sed -n 's|\S*: \(\w*\):.*|\1|p')


echo "Bootstrap base pkgs" ; sleep 3
#rm -r /mnt/var/lib/rpm /mnt/var/cache/zypp
#mkdir -p /mnt/var/lib/rpm /mnt/var/cache/zypp
#rpm -v --root /mnt --initdb
# [wget -O file url | curl -L -o file url]
#wget -O /tmp/release.rpm http://${MIRROR}/distribution/${RELEASE}/repo/oss/${UNAME_M}/openSUSE-release-15.2-lp152.575.1.${UNAME_M}.rpm
#rpm -v -qip /tmp/release.rpm ; sleep 5
#rpm -v --root /mnt --nodeps -i /tmp/release.rpm
zypper --non-interactive --root /mnt --gpg-auto-import-keys addrepo http://${MIRROR}/distribution/${RELEASE}/repo/oss/ repo-oss
zypper --non-interactive --root /mnt --gpg-auto-import-keys refresh
zypper --non-interactive --root /mnt install --no-recommends patterns-base-base makedev system-group-wheel
zypper --non-interactive --root /mnt repos ; sleep 5


echo "Prepare chroot (mount --[r]bind devices)" ; sleep 3
cp /etc/mtab /mnt/etc/mtab
mkdir -p /mnt/dev /mnt/proc /mnt/sys /mnt/run
mount --rbind /proc /mnt/proc ; mount --rbind /sys /mnt/sys
mount --rbind /dev /mnt/dev

mount --rbind /dev/pts /mnt/dev/pts ; mount --rbind /run /mnt/run
modprobe efivarfs
mount -t efivarfs efivarfs /mnt/sys/firmware/efi/efivars/


#mkdir -p /mnt/var/empty /mnt/var/lock/subsys /mnt/etc/sysconfig/network
#cp /etc/sysconfig/network/ifcfg-$ifdev /mnt/etc/sysconfig/network/ifcfg-${ifdev}.bak
mkdir -p /mnt/run/netconfig ; touch /mnt/run/netconfig/resolv.conf
cp /etc/resolv.conf /mnt/etc/resolv.conf


# LANG=[C|en_US].UTF-8
cat << EOFchroot | LANG=C.UTF-8 LANGUAGE=en chroot /mnt /bin/sh
set -x

chmod 1777 /tmp ; chmod 1777 /var/tmp
chown root:root / ; chmod 0755 /

unset LC_ALL
export TERM=xterm-color     # xterm | xterm-color
#hostname ${INIT_HOSTNAME}

ls /proc ; sleep 5 ; ls /dev ; sleep 5

#mount -t proc none /proc
cd /dev ; MAKEDEV generic

systemctl stop sshd ; systemctl disable sshd

echo "Config pkg repo mirror(s)" ; sleep 3
. /etc/os-release
zypper --non-interactive --gpg-auto-import-keys addrepo http://${MIRROR}/distribution/leap/\${VERSION_ID}/repo/oss/ repo-oss
zypper --non-interactive --gpg-auto-import-keys addrepo http://${MIRROR}/distribution/leap/\${VERSION_ID}/repo/non-oss/ repo-non-oss
zypper --non-interactive --gpg-auto-import-keys addrepo http://${MIRROR}/update/leap/\${VERSION_ID}/oss/ update-oss
zypper --non-interactive --gpg-auto-import-keys addrepo http://${MIRROR}/update/leap/\${VERSION_ID}/non-oss/ update-non-oss
zypper repos ; sleep 5


echo "Add software package selection(s)" ; sleep 3
zypper --non-interactive --gpg-auto-import-keys refresh
zypper --non-interactive install --no-recommends patterns-base-base patterns-base-bootloader patterns-yast-yast2_basis
zypper --non-interactive install --no-recommends --type pattern base bootloader yast2_basis
# xfce
# laptop

zypper --non-interactive install ca-certificates-cacert ca-certificates-mozilla
zypper --gpg-auto-import-keys refresh
update-ca-certificates
zypper --non-interactive install kernel-default makedev system-group-wheel sudo nano less dosfstools xfsprogs grub2 shim efibootmgr firewalld openssl openssh-askpass btrfsprogs

modprobe btrfs


echo "Config keyboard ; localization" ; sleep 3
kbd_mode -u ; loadkeys us ## ?? error
sed -i '/en_US.UTF-8 UTF-8/ s|^# ||' /etc/locale.gen
echo 'LANG=en_US.UTF-8' >> /etc/locale.conf
locale-gen # en_US en_US.UTF-8

#sh -c 'cat >> /etc/default/locale' << EOF
#LANG=en_US.UTF-8
##LC_ALL=en_US.UTF-8
#LANGUAGE="en_US:en"
#
#EOF


echo "Config time zone & clock" ; sleep 3
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

sh -c "cat >> /etc/sysconfig/network/ifcfg-\${ifdev}" << EOF
BOOTPROTO='dhcp'
STARTMODE='auto'
ONBOOT='yes'

EOF
echo "NETWORKING=yes" >> /etc/sysconfig/network


echo "Set root passwd ; add user" ; sleep 3
groupadd --system wheel
#echo -n "root:${PASSWD_PLAIN}" | chpasswd
echo -n 'root:${PASSWD_CRYPTED}' | chpasswd -e

DIR_MODE=0750 useradd -m -G wheel -s /bin/bash -c 'Packer User' packer
#echo -n "packer:${PASSWD_PLAIN}" | chpasswd
echo -n 'packer:${PASSWD_CRYPTED}' | chpasswd -e
chown -R packer:\$(id -gn packer) /home/packer

sh -c 'cat >> /etc/sudoers.d/99_packer' << EOF
Defaults:packer !requiretty
#\$(id -un packer) ALL=(ALL) NOPASSWD: ALL
packer ALL=(ALL) NOPASSWD: ALL
EOF
chmod 0440 /etc/sudoers.d/99_packer


sed -i "/^%wheel.*(ALL)\s*ALL/ s|%wheel|# %wheel|" /etc/sudoers
sed -i "/^#.*%wheel.*NOPASSWD.*/ s|^#.*%wheel|%wheel|" /etc/sudoers
echo '%wheel ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers
sed -i "s|^[^#].*requiretty|# Defaults requiretty|" /etc/sudoers


echo "Config dracut ; Linux kernel"
mkdir -p /etc/dracut.conf.d

echo 'hostonly="yes"' >> /etc/dracut.conf

sleep 10 ; echo 'First try'
kernel-install add \$(uname -r) /boot/vmlinuz-\$(uname -r)
dracut --kver \$(uname -r) --force
mkinitrd /boot/initrd-\$(uname -r) \$(uname -r)

sleep 10 ; echo 'Try again'
kver="\$(ls -A /lib/modules/ | tail -1)"
kernel-install add \$kver /boot/vmlinuz-\$kver
dracut --kver \$kver --force
mkinitrd /boot/initrd-\$kver \$kver


echo "Bootloader installation & config" ; sleep 3
mkdir -p /boot/efi/EFI/\${ID} /boot/efi/EFI/BOOT
if [ "aarch64" = "${UNAME_M}" ] ; then
  grub2-install --target=arm64-efi --efi-directory=/boot/efi --bootloader-id=\${ID} --recheck --removable ;
  cp -R /boot/efi/EFI/\${ID}/* /boot/efi/EFI/BOOT/ ;
  cp /boot/efi/EFI/BOOT/BOOTAA64.EFI /boot/efi/EFI/BOOT/BOOTAA64.EFI.bak ;
  cp /boot/efi/EFI/BOOT/grubaa64.EFI /boot/efi/EFI/BOOT/BOOTAA64.EFI ;
  #cp /boot/efi/EFI/\${ID}/grubaa64.efi /boot/efi/EFI/BOOT/BOOTAA64.EFI ;
else
  grub2-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=\${ID} --recheck --removable ;
  grub2-install --target=i386-pc --recheck /dev/$DEVX ;
  cp -R /boot/efi/EFI/\${ID}/* /boot/efi/EFI/BOOT/ ;
  cp /boot/efi/EFI/BOOT/BOOTX64.EFI /boot/efi/EFI/BOOT/BOOTX64.EFI.bak ;
  cp /boot/efi/EFI/BOOT/grubx64.EFI /boot/efi/EFI/BOOT/BOOTX64.EFI ;
  #cp /boot/efi/EFI/\${ID}/grubx64.efi /boot/efi/EFI/BOOT/BOOTX64.EFI ;
fi

#sed -i -e "s|^GRUB_TIMEOUT=.*$|GRUB_TIMEOUT=1|" /etc/default/grub
#sed -i -e "/GRUB_DEFAULT/ s|=.*$|=saved|" /etc/default/grub
#echo "GRUB_SAVEDEFAULT=true" >> /etc/default/grub
#echo "#GRUB_CMDLINE_LINUX='cryptdevice=/dev/sda2:cryptroot'" >> /etc/default/grub
echo 'GRUB_PRELOAD_MODULES="btrfs"' >> /etc/default/grub
sed -i '/GRUB_CMDLINE_LINUX_DEFAULT/ s|="\(.*\)"|="\1 text xdriver=vesa nomodeset rootdelay=5"|'  \
  /etc/default/grub
if [ "\$(dmesg | grep -ie 'Hypervisor detected')" ] ; then
  sed -i -e '/GRUB_CMDLINE_LINUX_DEFAULT/ s|="\(.*\)"|="\1 net.ifnames=0 biosdevname=0"|' /etc/default/grub ;
fi
grub2-mkconfig -o /boot/grub2/grub.cfg
#cp -f /boot/efi/EFI/\${ID}/grub.cfg /boot/grub2/grub.cfg
#cp -f /boot/efi/EFI/\${ID}/grub.cfg /boot/efi/EFI/BOOT/grub.cfg

if [ "aarch64" = "${UNAME_M}" ] ; then
  efibootmgr -c -d /dev/$DEVX -p \$(lsblk -nlpo name,label,partlabel | sed -n '/ESP/ s|.*[sv]da\([0-9]*\).*|\1|p') -l "/EFI/\${ID}/grubaa64.efi" -L \${ID}
  efibootmgr -c -d /dev/$DEVX -p \$(lsblk -nlpo name,label,partlabel | sed -n '/ESP/ s|.*[sv]da\([0-9]*\).*|\1|p') -l "/EFI/BOOT/BOOTAA64.EFI" -L Default
else
  efibootmgr -c -d /dev/$DEVX -p \$(lsblk -nlpo name,label,partlabel | sed -n '/ESP/ s|.*[sv]da\([0-9]*\).*|\1|p') -l "/EFI/\${ID}/grubx64.efi" -L \${ID}
  efibootmgr -c -d /dev/$DEVX -p \$(lsblk -nlpo name,label,partlabel | sed -n '/ESP/ s|.*[sv]da\([0-9]*\).*|\1|p') -l "/EFI/BOOT/BOOTX64.EFI" -L Default
fi
efibootmgr -v ; sleep 3


zypper --non-interactive clean
fstrim -av
sync


# enable ssh just before finish
systemctl enable sshd
systemctl disable firewalld

exit

EOFchroot
# end chroot commands

tar -xf /tmp/scripts.tar -C /mnt/root/ ; sleep 5

read -p "Enter 'y' if ready to unmount & reboot [yN]: " response
if [ "y" = "$response" ] || [ "Y" = "$response" ] ; then
  sync ; swapoff -va ; umount -vR /mnt ;
  reboot ; #poweroff ;
fi
