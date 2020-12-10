#!/bin/bash -x

# nc -l [-p] {port} > file ## nc -w3 {host} {port} < file  # netcat xfr
# ssh user@ipaddr "su -c 'sh -xs - arg1 argN'" < script.sh
# ssh user@ipaddr "sudo sh -xs - arg1 argN" < script.sh  # w/ sudo

#sh /tmp/disk_setup.sh part_vmdisk sgdisk lvm vg0 pvol0
#sh /tmp/disk_setup.sh format_partitions lvm vg0 pvol0
#sh /tmp/disk_setup.sh mount_filesystems vg0

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
export MIRROR=${MIRROR:-mirrors.kernel.org/mageia}
BASEARCH=${BASEARCH:-x86_64} ; RELEASE=${RELEASE:-7.1}

export INIT_HOSTNAME=${1:-mageia-boxv0000}
#export PLAIN_PASSWD=${2:-abcd0123}
export CRYPTED_PASSWD=${2:-\$6\$16CHARACTERSSALT\$o/XwaDmfuxBWVf1nEaH34MYX8YwFlAMo66n1.L3wvwdalv0IaV2b/ajr7xNcX/RFIPvfBNj.2Qxeh7v4JTjJ91}

export YUMCMD="yum --setopt=requires_policy=strong --setopt=group_package_types=mandatory --releasever=${RELEASE}"
export DNFCMD="dnf --setopt=install_weak_deps=False --releasever=${RELEASE}"


echo "Create /etc/fstab" ; sleep 3
mkdir -p /mnt/etc /mnt/media ; chmod 0755 /mnt/media
sh -c 'cat > /mnt/etc/fstab' << EOF
LABEL=${GRP_NM}-osRoot   /           ext4    errors=remount-ro   0   1
LABEL=${GRP_NM}-osVar    /var        ext4    defaults    0   2
LABEL=${GRP_NM}-osHome   /home       ext4    defaults    0   2
LABEL=ESP      /boot/efi   vfat    umask=0077  0   2
LABEL=${GRP_NM}-osSwap   none        swap    sw          0   0

proc                            /proc       proc    defaults    0   0
sysfs                           /sys        sysfs   defaults    0   0

EOF


echo "Bootstrap base pkgs" ; sleep 3
if command -v dnf > /dev/null ; then
  #${DNFCMD} --nogpgcheck -y --installroot=/mnt --repofrompath=quickrepo${RELEASE},http://${MIRROR}/distrib/${RELEASE}/${BASEARCH}/media/core/release/ --repo=quickrepo${RELEASE} install urpmi dnf dnf-plugins-core locales-en lvm2 ;
  ${DNFCMD} --nogpgcheck -y --installroot=/mnt config-manager --add-repo http://${MIRROR}/distrib/${RELEASE}/${BASEARCH}/media/core/release ;
  dnf -y --installroot=/mnt check-update ;
  ${DNFCMD} --nogpgcheck -y --installroot=/mnt install basesystem-minimal-core urpmi dnf dnf-plugins-core makedev ;
  dnf -y --installroot=/mnt repolist ;
elif command -v yum-config-manager > /dev/null ; then
  rm -r /mnt/var/lib/rpm /mnt/var/cache/dnf ;
  mkdir -p /mnt/var/lib/rpm /mnt/var/cache/dnf ;
  rpm -v --root /mnt --initdb ;
  # [wget -O file url | curl -L -o file url]
  #wget -O /tmp/repos.rpm http://${MIRROR}/distrib/${RELEASE}/${BASEARCH}/media/core/release/mageia-repos-7-3.mga7.${BASEARCH}.rpm ;
  #rpm -v -qip /tmp/repos.rpm ; sleep 5 ;
  #rpm -v --root /mnt --nodeps -i /tmp/repos.rpm ;
  yum-config-manager --releasever=${RELEASE} --nogpgcheck -y --installroot=/mnt --add-repo http://${MIRROR}/distrib/${RELEASE}/${BASEARCH}/media/core/release ;
  yum -y --installroot=/mnt check-update ;
  ${YUMCMD} --nogpgcheck -y --installroot=/mnt install basesystem-minimal-core urpmi dnf dnf-plugins-core makedev ;
  yum -y --installroot=/mnt repolist ;
elif command -v urpmi > /dev/null ; then
  #urpmi.addmedia --urpmi-root /mnt --distrib --mirrorlist '$MIRRORLIST'
	urpmi.addmedia --urpmi-root /mnt --distrib http://${MIRROR}/distrib/${RELEASE}/${BASEARCH} ;
	urpmi.update --urpmi-root /mnt -a ;
	urpmi --no-recommends --auto --urpmi-root /mnt basesystem-minimal-core urpmi dnf dnf-plugins-core makedev ;
	urpmq --list-url ;
fi
sleep 5


echo "Prepare chroot (mount --[r]bind devices)" ; sleep 3
cp /etc/mtab /mnt/etc/mtab
mkdir -p /mnt/dev /mnt/proc /mnt/sys /mnt/run
mount --rbind /proc /mnt/proc ; mount --rbind /sys /mnt/sys
mount --rbind /dev /mnt/dev

mount --rbind /dev/pts /mnt/dev/pts ; mount --rbind /run /mnt/run
modprobe efivarfs
mount -t efivarfs efivarfs /mnt/sys/firmware/efi/efivars/


#mkdir -p /mnt/var/empty /mnt/var/lock/subsys /mnt/etc/sysconfig/network-scripts
#cp /etc/sysconfig/network-scripts/ifcfg-$ifdev /mnt/etc/sysconfig/network-scripts/ifcfg-${ifdev}.bak
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
#cd /dev ; MAKEDEV generic


echo "Config pkg repo mirror(s)" ; sleep 3
. /etc/os-release
#urpmi.update -a
##urpmi.addmedia --distrib --mirrorlist '$MIRRORLIST'
#urpmi.addmedia --distrib http://${MIRROR}/distrib/\${VERSION_ID}/${BASEARCH}
#urpmq --list-url ; sleep 5
${DNFCMD} config-manager --set-enabled \${ID}-${BASEARCH} updates-${BASEARCH}
${DNFCMD} -y --refresh distro-sync
#cat /etc/yum.repos.d/* ; sleep 5
${DNFCMD} -y repolist enabled ; sleep 5


echo "Add software package selection(s)" ; sleep 3
pkgs_nms="basesystem kernel-desktop-latest microcode_ctl locales-en sudo dhcp-client man-pages dosfstools openssh-server nano mandi-ifw shorewall shorewall-ipv6 urpmi dnf dnf-plugins-core harddrake-ui grub grub2-efi efibootmgr lvm2" # task-xfce"
#urpmi.update -a
#urpmi --no-recommends --auto \$pkgs_nms
${DNFCMD} -y check-update
${DNFCMD} -y install \$pkgs_nms

modprobe dm-mod ; vgscan ; vgchange -ay ; lvs


echo "Config keyboard ; localization" ; sleep 3
kbd_mode -u ; loadkeys us
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
#resolvconf -u
#sh -c 'cat >> /etc/resolv.conf' << EOF
##search hqdom.local
#nameserver 8.8.8.8
#
#EOF

cat /etc/resolv.conf ; sleep 5
sed -i '/127.0.1.1/d' /etc/hosts
echo "127.0.1.1    ${INIT_HOSTNAME}.localdomain    ${INIT_HOSTNAME}" >> /etc/hosts

ifdev=\$(ip -o link | grep 'link/ether' | grep 'LOWER_UP' | sed -n 's|\S*: \(\w*\):.*|\1|p')

#sh -c "cat >> /etc/sysconfig/network-scripts/ifcfg-\$ifdev" << EOF
#BOOTPROTO=dhcp
#STARTMODE=auto
#ONBOOT=yes
##DHCP_CLIENT=dhclient
#
#EOF
sh -c "cat >> /etc/sysconfig/network" << EOF
NETWORKING=yes
CRDA_DOMAIN=US
HOSTNAME=${INIT_HOSTNAME}

EOF


echo "Update services" ; sleep 3
#drakfirewall ; sleep 5
service shorewall stop ; service shorewall6 stop
systemctl disable shorewall ; systemctl disable shorewall6
service -s ; service --status-all ; sleep 5


echo "Set root passwd ; add user" ; sleep 3
groupadd --system wheel
#echo -n "root:${PLAIN_PASSWD}" | chpasswd
echo -n 'root:${CRYPTED_PASSWD}' | chpasswd -e

DIR_MODE=0750 useradd -m -G wheel -s /bin/bash -c 'Packer User' packer
#echo -n "packer:${PLAIN_PASSWD}" | chpasswd
echo -n 'packer:${CRYPTED_PASSWD}' | chpasswd -e
chown -R packer:\$(id -gn packer) /home/packer

#sh -c 'cat >> /etc/sudoers.d/99_packer' << EOF
#Defaults:packer !requiretty
#\$(id -un packer) ALL=(ALL) NOPASSWD: ALL
#EOF
#chmod 0440 /etc/sudoers.d/99_packer


sed -i "/^%wheel.*(ALL)\s*ALL/ s|%wheel|# %wheel|" /etc/sudoers
sed -i "/^#.*%wheel.*NOPASSWD.*/ s|^#.*%wheel|%wheel|" /etc/sudoers
echo '%wheel ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers
sed -i "s|^[^#].*requiretty|# Defaults requiretty|" /etc/sudoers


echo "Bootloader installation & config" ; sleep 3
mkdir -p /boot/efi/EFI/\${ID} /boot/efi/EFI/BOOT
grub2-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=\${ID} --recheck --removable
grub2-install --target=i386-pc --recheck /dev/$DEVX
cp -R /boot/efi/EFI/\${ID}/* /boot/efi/EFI/BOOT/
cp /boot/efi/EFI/BOOT/BOOTX64.EFI /boot/efi/EFI/BOOT/BOOTX64.EFI.bak
cp /boot/efi/EFI/BOOT/grubx64.EFI /boot/efi/EFI/BOOT/BOOTX64.EFI

#sed -i -e "s|^GRUB_TIMEOUT=.*$|GRUB_TIMEOUT=1|" /etc/default/grub
#sed -i -e "/GRUB_DEFAULT/ s|=.*$|=saved|" /etc/default/grub
#echo "GRUB_SAVEDEFAULT=true" >> /etc/default/grub
#echo "#GRUB_CMDLINE_LINUX='cryptdevice=/dev/sda2:cryptroot'" >> /etc/default/grub
echo 'GRUB_PRELOAD_MODULES="lvm"' >> /etc/default/grub
sed -i '/GRUB_CMDLINE_LINUX_DEFAULT/ s|="\(.*\)"|="\1 text xdriver=vesa nomodeset rootdelay=5"|'  \
  /etc/default/grub
grub2-mkconfig -o /boot/grub2/grub.cfg
#cp -f /boot/efi/EFI/\${ID}/grub.cfg /boot/grub2/grub.cfg
#cp -f /boot/efi/EFI/\${ID}/grub.cfg /boot/efi/EFI/BOOT/grub.cfg

efibootmgr -c -d /dev/$DEVX -p \$(lsblk -nlpo name,label,partlabel | sed -n '/ESP/ s|.*[sv]da\([0-9]*\).*|\1|p') -l "/EFI/\${ID}/grubx64.efi" -L \${ID}
efibootmgr -c -d /dev/$DEVX -p \$(lsblk -nlpo name,label,partlabel | sed -n '/ESP/ s|.*[sv]da\([0-9]*\).*|\1|p') -l "/EFI/BOOT/BOOTX64.EFI" -L Default
efibootmgr -v ; sleep 3


# enable ssh just before finish
systemctl enable sshd


${DNFCMD} -y clean all
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
