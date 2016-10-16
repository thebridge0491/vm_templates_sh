#!/bin/sh -x

# nc -l [-p] {port} > file ## nc -w3 {host} {port} < file  # netcat xfr
# ssh user@ipaddr "su -c 'sh -xs - arg1 argN'" < script.sh
# ssh user@ipaddr "sudo sh -xs - arg1 argN" < script.sh  # w/ sudo

#sh /tmp/disk_setup.sh part_vmdisk sfdisk lvm vg0 pvol0
#sh /tmp/disk_setup.sh format_partitions lvm vg0 pvol0
#sh /tmp/disk_setup.sh mount_filesystems vg0

# passwd crypted hash: [md5|sha256|sha512] - [$1|$5|$6]$...
# python -c "import crypt,getpass ; print(crypt.crypt(getpass.getpass(), '\$6\$16CHARACTERSSALT'))"
# perl -e "print crypt('password', '\$6\$16CHARACTERSSALT') . \"\n\""

set -x

export DEVX=${DEVX:-sda} ; export GRP_NM=${GRP_NM:-vg0}
export MIRROR=${MIRROR:-mirror.math.princeton.edu/pub/debian}
ADD_VAGRANTUSER=${ADD_VAGRANTUSER:-0}

#export PLAIN_PASSWD=${1:-abcd0123}
export CRYPTED_PASSWD=${1:-\$6\$16CHARACTERSSALT\$o/XwaDmfuxBWVf1nEaH34MYX8YwFlAMo66n1.L3wvwdalv0IaV2b/ajr7xNcX/RFIPvfBNj.2Qxeh7v4JTjJ91}
export INIT_HOSTNAME=${2:-debian-boxv0000}

service ssh stop


echo "Create/edit /etc/fstab" ; sleep 3
mkdir -p /mnt/etc /mnt/media ; chmod 0755 /mnt/media
sh -c 'cat >> /mnt/etc/fstab' << EOF
LABEL=${GRP_NM}-osRoot   /           ext4    errors=remount-ro   0   1
LABEL=${GRP_NM}-osVar    /var        ext4    defaults    0   2
LABEL=${GRP_NM}-osHome   /home       ext4    defaults    0   2
LABEL=ESP      /boot/efi   vfat    umask=0077  0   2
LABEL=${GRP_NM}-osSwap   none        swap    sw          0   0

proc                            /proc       proc    defaults    0   0
sysfs                           /sys        sysfs   defaults    0   0

EOF


#VERSION_ID=$(sed -n 's|VERSION_ID="*\(.*\)"*|\1|p' /etc/os-release)
OS_ID=$(sed -n 's|^ID="*\(.*\)"*|\1|p' /etc/os-release)
VERSION_CODENAME=${VERSION_CODENAME:-$(sed -n 's|VERSION_CODENAME="*\(.*\)"*|\1|p' /etc/os-release)}

apt-get --yes update
apt-get --yes install --no-install-recommends debootstrap bash efibootmgr

modprobe dm-mod ; modprobe dm-crypt ; lsmod | grep -e dm_mod -e dm_crypt
modprobe efivarfs

ifdev=$(ip -o link | grep 'link/ether' | grep 'LOWER_UP' | sed -n 's|\S*: \(\w*\):.*|\1|p')


echo "Bootstrap base pkgs" ; sleep 3
#debootstrap --no-check-gpg --arch amd64 --variant minbase $VERSION_CODENAME /mnt file:/cdrom/${OS_ID}/
debootstrap --arch amd64 $VERSION_CODENAME /mnt http://${MIRROR}


cp /etc/resolv.conf /mnt/etc/resolv.conf

echo "Prepare chroot (mount --bind devices)" ; sleep 3
cp /etc/mtab /mnt/etc/mtab
mkdir -p /mnt/dev /mnt/proc /mnt/sys /mnt/hostlvm /mnt/hostudev /mnt/run
mount --bind /proc /mnt/proc ; mount --bind /sys /mnt/sys
mount --bind /dev /mnt/dev ; mount --bind /dev/pts /mnt/dev/pts

mount -t efivarfs efivarfs /mnt/sys/firmware/efi/efivars/
mount --bind /run/lvm /mnt/hostlvm ; mount --bind /run/udev /mnt/hostudev


# LANG=[C|en_US].UTF-8
cat << EOFchroot | LANG=C.UTF-8 LANGUAGE=en chroot /mnt /bin/sh
set -x

unset LC_ALL
export TERM=xterm-color     # xterm | xterm-color

ls /proc ; sleep 5 ; ls /dev ; sleep 5


apt-get --yes install --no-install-recommends makedev
mount -t proc none /proc
cd /dev ; MAKEDEV generic
ln -s /hostlvm /run/lvm ; ln -s /hostudev /run/udev


echo "Config pkg repo components(main contrib non-free)" ; sleep 3
cp /etc/apt/sources.list /etc/apt/sources.list.old
sed -i '/main.*$/ s|main.*$|main contrib non-free|' /etc/apt/sources.list
sed -i '/^#[ ]*deb/ s|^#||' /etc/apt/sources.list
sed -i '/^[ ]*deb cdrom:/ s|^|#|' /etc/apt/sources.list
cat /etc/apt/sources.list ; sleep 5


echo "Add software package selection(s)" ; sleep 3
apt-get --yes update
apt-get --yes install --no-install-recommends linux-image-amd64 grub-efi-amd64 grub-pc-bin sudo linux-headers-amd64 openssh-server lvm2
#tasksel install standard lxde-desktop
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
echo -e "127.0.1.1\t${INIT_HOSTNAME}.localdomain\t${INIT_HOSTNAME}" >> /etc/hosts

sh -c 'cat >> /etc/network/interfaces' << EOF
auto lo
iface lo inet loopback

auto ${ifdev}
allow-hotplug ${ifdev}
iface ${ifdev} inet dhcp
iface ${ifdev} inet6 auto

#auto wlan0
#iface wlan0 inet dhcp
#   wireless-essid  ????
#   wireless-mode   ????

EOF


echo "Set root passwd ; add user" ; sleep 3
#echo -n "root:${PLAIN_PASSWD}" | chpasswd
echo -n 'root:${CRYPTED_PASSWD}' | chpasswd -e

DIR_MODE=0750 useradd -m -G operator,sudo -c 'Packer User' packer
#echo -n "packer:${PLAIN_PASSWD}" | chpasswd
echo -n 'packer:${CRYPTED_PASSWD}' | chpasswd -e
chown -R packer:\$(id -gn packer) /home/packer

#sh -c 'cat >> /etc/sudoers.d/99_packer' << EOF
#Defaults:packer !requiretty
#\$(id -un packer) ALL=(ALL) NOPASSWD: ALL
#EOF
#chmod 0440 /etc/sudoers.d/99_packer


if [ ! "0" = "${ADD_VAGRANTUSER}" ] ; then
DIR_MODE=0750 useradd -m -G operator,sudo -s /bin/bash -c 'Vagrant User' vagrant ;
echo -n "vagrant:vagrant" | chpasswd ;
chown -R vagrant:\$(id -gn vagrant) /home/vagrant ;

#sh -c 'cat > /etc/sudoers.d/99_vagrant' << EOF ;
#Defaults:vagrant !requiretty
#\$(id -un vagrant) ALL=(ALL) NOPASSWD: ALL
#
#EOF
#chmod 0440 /etc/sudoers.d/99_vagrant ;
fi


sed -i "/^%sudo.*(ALL)\s*ALL/ s|%sudo|# %sudo|" /etc/sudoers
#sed -i "/^#.*%sudo.*NOPASSWD.*/ s|^#.*%sudo|%sudo|" /etc/sudoers
echo '%sudo ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers
sed -i "s|^[^#].*requiretty|# Defaults requiretty|" /etc/sudoers


sh -c 'cat >> /etc/ssh/sshd_config' << EOF
TrustedUserCAKeys /etc/ssh/sshca-id_ed25519.pub
RevokedKeys /etc/ssh/krl.krl
#HostCertificate /etc/ssh/ssh_host_ed25519_key-cert.pub
#HostCertificate /etc/ssh/ssh_host_ecdsa_key-cert.pub
#HostCertificate /etc/ssh/ssh_host_rsa_key-cert.pub

EOF


echo "Bootloader installation & config" ; sleep 3
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=${OS_ID} --recheck --removable
grub-install --target=i386-pc --recheck /dev/$DEVX
mkdir -p /boot/efi/EFI/BOOT
cp -R /boot/efi/EFI/${OS_ID}/* /boot/efi/EFI/BOOT/
cp /boot/efi/EFI/BOOT/BOOTX64.EFI /boot/efi/EFI/BOOT/BOOTX64.EFI.bak
cp /boot/efi/EFI/BOOT/grubx64.EFI /boot/efi/EFI/BOOT/BOOTX64.EFI

#sed -i -e "s|^GRUB_TIMEOUT=.*$|GRUB_TIMEOUT=1|" /etc/default/grub
#sed -i -e "/GRUB_DEFAULT/ s|=.*$|=saved|" /etc/default/grub
#echo "GRUB_SAVEDEFAULT=true" >> /etc/default/grub
#echo "#GRUB_CMDLINE_LINUX='cryptdevice=/dev/sda2:cryptroot'" >> /etc/default/grub
echo 'GRUB_PRELOAD_MODULES="lvm"' >> /etc/default/grub
sed -i '/GRUB_CMDLINE_LINUX_DEFAULT/ s|="\(.*\)"|="\1 rootdelay=5"|'  \
  /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

exit

EOFchroot
# end chroot commands

for fileX in /tmp/disk_setup.sh /tmp/install.sh ; do
  cp $fileX /mnt/root/ ;
done
sync

IDX_ESP=$(lsblk -nlpo name,label,partlabel | sed -n '/ESP/ s|.*[sv]da\([0-9]*\).*|\1|p')
efibootmgr -v ; sleep 3
efibootmgr -c -d /dev/$DEVX -p $IDX_ESP -l "\EFI\${OS_ID}\grubx64.efi" -L ${OS_ID}
efibootmgr -c -d /dev/$DEVX -p $IDX_ESP -l '\EFI\BOOT\BOOTX64.EFI' -L Default

sync ; swapoff -va ; umount -vR /mnt
reboot #poweroff
