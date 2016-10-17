#!/bin/sh -x

# nc -l [-p] {port} > file ## nc -w3 {host} {port} < file  # netcat xfr
# ssh user@ipaddr "su -c 'sh -xs - arg1 argN'" < script.sh
# ssh user@ipaddr "sudo sh -xs - arg1 argN" < script.sh  # w/ sudo

#sh /tmp/disk_setup.sh part_vmdisk sgdisk lvm vg0 pvol0
#sh /tmp/disk_setup.sh format_partitions lvm vg0 pvol0
#sh /tmp/disk_setup.sh mount_filesystems vg0

# passwd crypted hash: [md5|sha256|sha512] - [$1|$5|$6]$...
# python -c 'import crypt,getpass ; print(crypt.crypt(getpass.getpass(), "$6$16CHARACTERSSALT"))'
# perl -e 'print crypt("password", "\$6\$16CHARACTERSSALT") . "\n"'

set -x

export DEVX=${DEVX:-sda} ; export GRP_NM=${GRP_NM:-vg0}
export MIRROR=${MIRROR:-spout.ussg.indiana.edu}
ADD_VAGRANTUSER=${ADD_VAGRANTUSER:-0}

export PLAIN_PASSWD=${1:-abcd0123}
#export CRYPTED_PASSWD=${1:-\$6\$16CHARACTERSSALT\$o/XwaDmfuxBWVf1nEaH34MYX8YwFlAMo66n1.L3wvwdalv0IaV2b/ajr7xNcX/RFIPvfBNj.2Qxeh7v4JTjJ91}
export INIT_HOSTNAME=${2:-pclinuxos-boxv0000}

echo "Create/edit /etc/fstab" ; sleep 3
mkdir -p /mnt/etc /mnt/media ; chmod 0755 /mnt/media
sh -c 'cat >> /mnt/etc/fstab' << EOF
LABEL=${GRP_NM}-osRoot    /           ext4    errors=remount-ro   0   1
LABEL=${GRP_NM}-osVar     /var        ext4    defaults    0   2
LABEL=${GRP_NM}-osHome    /home       ext4    defaults    0   2
LABEL=ESP      /boot/efi   vfat    umask=0077  0   2
LABEL=${GRP_NM}-osSwap    none        swap    sw          0   0

proc                            /proc       proc    defaults    0   0
sysfs                           /sys        sysfs   defaults    0   0

EOF

OS_ID=$(sed -n 's|^ID="*\(.*\)"*|\1|p' /etc/os-release)


sed -i 's|^[ ]*rpm|# rpm|' /etc/apt/sources.list
sed -i "/${MIRROR}/ s|^.*rpm|rpm|" /etc/apt/sources.list
apt-get update
apt-get install -y lvm2 efibootmgr
# fix AND re-attempt install for infrequent errors
apt-get --root /mnt install --fix-broken -y
apt-get install -y lvm2 efibootmgr
service -s ; service --status-all ; sleep 3

modprobe dm-mod ; modprobe dm-crypt ; lsmod | grep -e dm_mod -e dm_crypt
modprobe efivarfs

vgscan ; vgchange -ay ; lvs


ifdev=$(ip -o link | grep 'link/ether' | grep 'LOWER_UP' | sed -n 's|\S*: \(\w*\):.*|\1|p')


echo "Bootstrap base pkgs" ; sleep 3
rpm --root /mnt --initdb # rpm --root /mnt --rebuilddb
#apt-get install -y --download-only bash ${OS_ID}-release
#rpm -qip /var/cache/apt/archives/${OS_ID}-release*.rpm ; sleep 5
#rpm --root /mnt --nodeps -i /var/cache/apt/archives/${OS_ID}-release*.rpm
apt-get --root /mnt install -y ${OS_ID}-release apt rpm locales-en lvm2
# fix AND re-attempt install for infrequent errors
apt-get --root /mnt install --fix-broken -y
apt-get --root /mnt install -y ${OS_ID}-release apt rpm locales-en lvm2


mkdir -p /mnt/var/empty /mnt/var/lock/subsys /mnt/etc/sysconfig/network-scripts
cp /etc/sysconfig/network-scripts/ifcfg-$ifdev /mnt/etc/sysconfig/network-scripts/ifcfg-${ifdev}.bak
cp /etc/resolv.conf /mnt/etc/resolv.conf

echo "Prepare chroot (mount --bind devices)" ; sleep 3
cp /etc/mtab /mnt/etc/mtab
mkdir -p /mnt/dev /mnt/proc /mnt/sys/firmware/efi/efivars /mnt/lib/modules
mount --bind /proc /mnt/proc ; mount --bind /sys /mnt/sys
mount --bind /dev /mnt/dev ; mount --bind /dev/pts /mnt/dev/pts

mount -t efivarfs efivarfs /mnt/sys/firmware/efi/efivars/


# LANG=[C|en_US].UTF-8
cat << EOFchroot | LANG=C.UTF-8 LANGUAGE=en chroot /mnt /bin/sh
set -x

unset LC_ALL
export TERM=xterm-color     # xterm | xterm-color

ls /proc ; sleep 5 ; ls /dev ; sleep 5


#mount -t proc none /proc
#cd /dev ; MAKEDEV generic


echo "Config pkg repo mirror(s)" ; sleep 3
sed -i 's|^[ ]*rpm|# rpm|' /etc/apt/sources.list
sed -i "/${MIRROR}/ s|^.*rpm|rpm|" /etc/apt/sources.list
grep -e '^rpm.*' /etc/apt/sources.list ; sleep 5


echo "Add software package selection(s)" ; sleep 3
apt-get update
apt-get --fix-broken install -y

pkgs_nms="basesystem microcode_ctl apt rpm locales-en sudo dhcp-client man-pages nano dosfstools lvm2 grub2 grub2-efi efibootmgr shorewall shorewall-ipv6 mandi-ifw" # task-lxde"
apt-get install -y \$pkgs_nms
# fix AND re-attempt install for infrequent errors
apt-get --fix-broken install -y
apt-get install -y \$pkgs_nms

modprobe dm-mod ; vgscan ; vgchange -ay ; lvs


echo "Config keyboard ; localization" ; sleep 3
kbd_mode -u ; loadkeys us
#sed -i '/en_US.UTF-8 UTF-8/ s|^# ||' /etc/locale.gen
#echo 'LANG=en_US.UTF-8' >> /etc/locale.conf
#locale-gen # en_US en_US.UTF-8

sh -c 'cat >> /etc/default/locale' << EOF
LANG=en_US.UTF-8
#LC_ALL=en_US.UTF-8
LANGUAGE="en_US:en"

EOF


echo "Config time zone & clock" ; sleep 3
rm /etc/localtime
ln -sf /usr/share/zoneinfo/UTC /etc/localtime
hwclock --systohc --utc


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
echo -e "127.0.1.1\t${INIT_HOSTNAME}.localdomain\t${INIT_HOSTNAME}" >> /etc/hosts

sh -c "cat >> /etc/sysconfig/network-scripts/ifcfg-$ifdev" << EOF
DEVICE=${ifdev}
BOOTPROTO=dhcp
STARTMODE=auto
ONBOOT=yes
DHCP_CLIENT=dhclient

EOF

sh -c "cat >> /etc/sysconfig/network" << EOF
NETWORKING=yes
CRDA_DOMAIN=US
HOSTNAME=${INIT_HOSTNAME}

EOF


echo "Update services" ; sleep 3
drakfirewall ; sleep 5 ; service shorewall stop ; service shorewall6 stop
service -s ; service --status-all ; sleep 5


echo "Set root passwd ; add user" ; sleep 3
groupadd --system wheel
echo -n "root:${PLAIN_PASSWD}" | chpasswd
#echo -n 'root:${CRYPTED_PASSWD}' | chpasswd -e

DIR_MODE=0750 useradd -m -G wheel -s /bin/bash -c 'Packer User' packer
echo -n "packer:${PLAIN_PASSWD}" | chpasswd
#echo -n 'packer:${CRYPTED_PASSWD}' | chpasswd -e
chown -R packer:\$(id -gn packer) /home/packer
DIR_MODE=0750 useradd -m -G wheel -s /bin/bash -c 'Packer User' packer
echo -n "packer:${PLAIN_PASSWD}" | chpasswd
#echo -n 'packer:${CRYPTED_PASSWD}' | chpasswd -e
chown -R packer:\$(id -gn packer) /home/packer

#sh -c 'cat >> /etc/sudoers.d/99_packer' << EOF
#Defaults:packer !requiretty
#\$(id -un packer) ALL=(ALL) NOPASSWD: ALL
#EOF
#chmod 0440 /etc/sudoers.d/99_packer


if [ ! "0" = "${ADD_VAGRANTUSER}" ] ; then
DIR_MODE=0750 useradd -m -G wheel -s /bin/bash -c 'Vagrant User' vagrant ;
echo -n "vagrant:vagrant" | chpasswd ;
chown -R vagrant:\$(id -gn vagrant) /home/vagrant ;

#sh -c 'cat > /etc/sudoers.d/99_vagrant' << EOF ;
#Defaults:vagrant !requiretty
#\$(id -un vagrant) ALL=(ALL) NOPASSWD: ALL
#
#EOF
#chmod 0440 /etc/sudoers.d/99_vagrant ;
fi


sed -i "/^%wheel.*(ALL)\s*ALL/ s|%wheel|# %wheel|" /etc/sudoers
sed -i "/^#.*%wheel.*NOPASSWD.*/ s|^#.*%wheel|%wheel|" /etc/sudoers
echo '%wheel ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers
sed -i "s|^[^#].*requiretty|# Defaults requiretty|" /etc/sudoers


sh -c 'cat >> /etc/ssh/sshd_config' << EOF
TrustedUserCAKeys /etc/ssh/sshca-id_ed25519.pub
RevokedKeys /etc/ssh/krl.krl
#HostCertificate /etc/ssh/ssh_host_ed25519_key-cert.pub
#HostCertificate /etc/ssh/ssh_host_ecdsa_key-cert.pub
#HostCertificate /etc/ssh/ssh_host_rsa_key-cert.pub

EOF


echo "Bootloader installation & config" ; sleep 3
grub2-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=${OS_ID} --recheck --removable
grub2-install --target=i386-pc --recheck /dev/$DEVX
mkdir -p /boot/efi/EFI/BOOT
cp -R /boot/efi/EFI/${OS_ID}/* /boot/efi/EFI/BOOT/
cp /boot/efi/EFI/BOOT/BOOTX64.EFI /boot/efi/EFI/BOOT/BOOTX64.EFI.bak
cp /boot/efi/EFI/BOOT/grubx64.EFI /boot/efi/EFI/BOOT/BOOTX64.EFI

#sed -i -e "s|^GRUB_TIMEOUT=.*$|GRUB_TIMEOUT=1|" /etc/default/grub
#sed -i -e "/GRUB_DEFAULT/ s|=.*$|=saved|" /etc/default/grub
#echo "GRUB_SAVEDEFAULT=true" >> /etc/default/grub
#echo "#GRUB_CMDLINE_LINUX='cryptdevice=/dev/sda2:cryptroot'" >> /etc/default/grub
echo 'GRUB_PRELOAD_MODULES="lvm"' >> /etc/default/grub
sed -i '/GRUB_CMDLINE_LINUX_DEFAULT/ s|="\(.*\)"|="\1 nokmsboot noacpi rootdelay=5"|'  \
  /etc/default/grub
grub2-mkconfig -o /boot/grub2/grub.cfg
#cp -f /boot/efi/EFI/${OS_ID}/grub.cfg /boot/grub2/grub.cfg
#cp -f /boot/efi/EFI/${OS_ID}/grub.cfg /boot/efi/EFI/BOOT/grub.cfg


apt-get --fix-broken install -y
# install/enable ssh just before finish
apt-get install -y openssh-server
service sshd stop #; service network stop

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
