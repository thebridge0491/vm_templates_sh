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

export GRP_NM=${GRP_NM:-vg0} ; export ZPOOLNM=${ZPOOLNM:-ospool0}
# [rocky/8|almalinux/8|centos/8-stream]/BaseOS/x86_64/os | centos/7/os/x86_64]
# (rocky) mirror: dl.rockylinux.org/pub/rocky
# (almalinux) mirror: repo.almalinux.org/almalinux
# (centos[-stream]) mirror: mirror.centos.org/centos
export MIRROR=${MIRROR:-mirror.centos.org/centos}
BASEARCH=${BASEARCH:-x86_64} ; RELEASE=${RELEASE:-8}
if [ "7" = "${RELEASE}" ] ; then
  REPO_DIRECTORY="/${RELEASE}/os/x86_64" ;
else
  REPO_DIRECTORY="/${RELEASE}/BaseOS/x86_64/os" ;
fi

export INIT_HOSTNAME=${1:-centos-boxv0000}
#export PLAIN_PASSWD=${2:-abcd0123}
export CRYPTED_PASSWD=${2:-\$6\$16CHARACTERSSALT\$o/XwaDmfuxBWVf1nEaH34MYX8YwFlAMo66n1.L3wvwdalv0IaV2b/ajr7xNcX/RFIPvfBNj.2Qxeh7v4JTjJ91}

export YUMCMD="yum --setopt=requires_policy=strong --setopt=group_package_types=mandatory --releasever=${RELEASE}"
export DNFCMD="dnf --setopt=install_weak_deps=False --releasever=${RELEASE}"

umount /mnt/boot/efi
DEV_ESP=$(lsblk -nlpo name,label,partlabel | grep -e ESP | cut -d' ' -f1)
yes | mkfs.fat -n ESP ${DEV_ESP}
mount ${DEV_ESP} /mnt/boot/efi

echo "Create /etc/fstab" ; sleep 3
mkdir -p /mnt/etc /mnt/media ; chmod 0755 /mnt/media
sh -c 'cat > /mnt/etc/fstab' << EOF
LABEL=${GRP_NM}-osBoot   /boot       ext2    defaults    0   2
LABEL=ESP      /boot/efi   vfat    umask=0077  0   2
LABEL=${GRP_NM}-osSwap   none        swap    sw          0   0

proc                            /proc       proc    defaults    0   0
sysfs                           /sys        sysfs   defaults    0   0

EOF


echo "Bootstrap base pkgs" ; sleep 3
zfs umount $ZPOOLNM/var/mail ; zfs destroy $ZPOOLNM/var/mail
if command -v dnf > /dev/null ; then
  #${DNFCMD} --nogpgcheck -y --installroot=/mnt --repofrompath=quickrepo${RELEASE},http://${MIRROR}${REPO_DIRECTORY}/ --repo=quickrepo${RELEASE} install basesystem bash dnf dnf-plugins-core yum yum-utils ;
  ${DNFCMD} --nogpgcheck -y --installroot=/mnt config-manager --add-repo http://${MIRROR}${REPO_DIRECTORY} ;
  ${DNFCMD} --installroot=/mnt check-update ;
  ${DNFCMD} --nogpgcheck -y --installroot=/mnt install basesystem bash dnf dnf-plugins-core yum yum-utils ;
  ${DNFCMD} --installroot=/mnt repolist ;
elif command -v yum-config-manager > /dev/null ; then
  rm -r /mnt/var/lib/rpm /mnt/var/cache/dnf ;
  mkdir -p /mnt/var/lib/rpm /mnt/var/cache/dnf ;
  rpm -v --root /mnt --initdb ;
  # [wget -O file url | curl -L -o file url]
  #wget -O /tmp/repos.rpm http://${MIRROR}${REPO_DIRECTORY}/Packages/centos-stream-repos-8-2.el8.noarch.rpm ;
  #rpm -v -qip /tmp/repos.rpm ; sleep 5 ;
  #rpm -v --root /mnt --nodeps -i /tmp/repos.rpm ;
  yum-config-manager --releasever=${RELEASE} --nogpgcheck -y --installroot=/mnt --add-repo http://${MIRROR}${REPO_DIRECTORY} ;
  ${YUMCMD} --installroot=/mnt check-update ;
  ${YUMCMD} --nogpgcheck -y --installroot=/mnt install basesystem bash dnf dnf-plugins-core yum yum-utils ;
  ${YUMCMD} --installroot=/mnt repolist ;
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

## temporarily disable SELinux to allow chpasswd in chroot
#setenforce 0 ; sestatus ; sleep 5

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
##cd /dev ; MAKEDEV generic


echo "Config pkg repo mirror(s)" ; sleep 3
. /etc/os-release ; VERSION_MAJOR=\$(echo \${VERSION_ID} | cut -d. -f1)
##yum-config-manager --add-repo http://mirrorlist.centos.org/?release=${RELEASE}&arch=${BASEARCH}&repo=baseos
#yum-config-manager --add-repo http://${MIRROR}/${RELEASE}/BaseOS/${BASEARCH}/os
#yum-config-manager --add-repo http://${MIRROR}/${RELEASE}/AppStream/${BASEARCH}/os
#yum-config-manager --add-repo http://${MIRROR}/${RELEASE}/extras/${BASEARCH}/os

yum -y check-update
${YUMCMD} -y reinstall dnf dnf-plugins-core yum yum-utils
${YUMCMD} -y install dnf dnf-plugins-core yum yum-utils
dnf --releasever=\${VERSION_MAJOR} -y install http://dl.fedoraproject.org/pub/epel/epel-release-latest-\${VERSION_MAJOR}.noarch.rpm
# Release version errors w/ CentOS Stream for EPEL/EPEL Modular
dnf --releasever=\${VERSION_MAJOR} config-manager --set-disabled epel epel-modular
#cat /etc/yum.repos.d/* ; sleep 5
dnf repolist ; sleep 5


echo "Add software package selection(s)" ; sleep 3
${DNFCMD} -y install @core linux-firmware microcode_ctl sudo tar kbd openssl grub2-pc grub2-efi-x64 grub2 efibootmgr
${DNFCMD} -y install network-scripts dhcp-client
# Use EL release kernel packages (avoid dkms build errors)
if [ "7" = "\${VERSION_MAJOR}" ] ; then
dnf --releasever=\${VERSION_MAJOR} -y --repofrompath quickrepo\${VERSION_MAJOR},http://${MIRROR}/\${VERSION_MAJOR}/os/${BASEARCH} --repo quickrepo\${VERSION_MAJOR} --enablerepo=epel install kernel
else
dnf --releasever=\${VERSION_MAJOR} -y --repofrompath quickrepo\${VERSION_MAJOR},http://${MIRROR}/\${VERSION_MAJOR}/BaseOS/${BASEARCH}/os --repo quickrepo\${VERSION_MAJOR} --enablerepo=epel --enablerepo=epel-modular install kernel
fi
dnf -y check-update
${DNFCMD} -y install 'dnf-command(versionlock)'


kver=\$(dnf list --installed kernel | sed -n 's|kernel[a-z0-9._]*[ ]*\([^ ]*\)[ ]*.*$|\1|p' | tail -n1)
echo \$kver ; sleep 5
# Use EL release kernel packages (avoid dkms build errors)
if [ "7" = "\${VERSION_MAJOR}" ] ; then
dnf --releasever=\${VERSION_MAJOR} -y --repofrompath quickrepo\${VERSION_MAJOR},http://${MIRROR}/\${VERSION_MAJOR}/os/${BASEARCH} --repo quickrepo\${VERSION_MAJOR} --enablerepo=epel install kernel-headers-\$kver.${BASEARCH} kernel-devel-\$kver.${BASEARCH} dkms
else
dnf --releasever=\${VERSION_MAJOR} -y --repofrompath quickrepo\${VERSION_MAJOR},http://${MIRROR}/\${VERSION_MAJOR}/BaseOS/${BASEARCH}/os --repo quickrepo\${VERSION_MAJOR} --enablerepo=epel --enablerepo=epel-modular install kernel-headers-\$kver.${BASEARCH} kernel-devel-\$kver.${BASEARCH} dkms
fi
${DNFCMD} -y install dracut-tools dracut-config-generic dracut-config-rescue
# @xfce-desktop
# @^minimal @minimal-environment redhat-lsb-core dracut-tools dracut-config-generic dracut-config-rescue


dnf --releasever=\${VERSION_MAJOR} -y install http://download.zfsonlinux.org/epel/zfs-release.el\${VERSION_ID/./_}.noarch.rpm
dnf repolist ; sleep 5
#dnf config-manager --set-disabled zfs
dnf --releasever=\${VERSION_MAJOR} --enablerepo=epel --enablerepo=epel-modular --enablerepo=zfs -y install zfs zfs-dracut ; sleep 3
echo REMAKE_INITRD=yes > /etc/dkms/zfs.conf
dkms status ; modprobe zfs ; zpool version ; sleep 5


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
sh -c "cat >> /etc/sysconfig/network-scripts/ifcfg-\$ifdev" << EOF
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


systemctl preset zfs-import.target ; systemctl preset zfs-mount
systemctl preset zfs.target ; systemctl preset zfs-zed
systemctl preset zfs-import-cache

systemctl enable zfs-import-cache ; systemctl enable zfs-import.target
systemctl enable zfs-mount ; systemctl enable zfs.target
sleep 10


echo "Set root passwd ; add user" ; sleep 3
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


sed -i "/^%wheel.*(ALL)\s*ALL/ s|%sudo|# %sudo|" /etc/sudoers
#sed -i "/^#.*%wheel.*NOPASSWD.*/ s|^#.*%wheel|%wheel|" /etc/sudoers
echo '%wheel ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers
sed -i "s|^[^#].*requiretty|# Defaults requiretty|" /etc/sudoers


echo "Config dracut"
echo 'hostonly="yes"' >> /etc/dracut.conf
mkdir -p /etc/dracut.conf.d
echo 'nofsck="yes"' >> /etc/dracut.conf.d/zol.conf
echo 'add_dracutmodules+=" zfs "' >> /etc/dracut.conf.d/zol.conf
echo 'omit_dracutmodules+=" btrfs resume "' >> /etc/dracut.conf.d/zol.conf

echo zfs > /etc/modules-load.d/zfs.conf # ??

dracut --force --kver \$kver.${BASEARCH}


grub2-probe /boot

echo "Hold zfs & kernel package upgrades (require manual upgrade)"
dnf versionlock add zfs zfs-dkms zfs-dracut kernel kernel-core kernel-modules kernel-tools kernel-tools-libs kernel-devel kernel-headers
dnf versionlock list ; sleep 3

echo "Bootloader installation & config" ; sleep 3
mkdir -p /boot/efi/EFI/\${ID} /boot/efi/EFI/BOOT
grub2-install --skip-fs-probe --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=\${ID} --recheck --removable
grub2-install --skip-fs-probe --target=i386-pc --recheck /dev/$DEVX
cp -R /boot/efi/EFI/\${ID}/* /boot/efi/EFI/BOOT/
cp /boot/efi/EFI/BOOT/BOOTX64.EFI /boot/efi/EFI/BOOT/BOOTX64.EFI.bak
cp /boot/efi/EFI/BOOT/grubx64.EFI /boot/efi/EFI/BOOT/BOOTX64.EFI

sh -c 'cat >> /etc/default/grub' << EOF
GRUB_TIMEOUT=5
GRUB_DISTRIBUTOR="\$(sed 's, release .*$,,g' /etc/system-release)"
GRUB_DEFAULT=saved
GRUB_DISABLE_SUBMENU=false
GRUB_TERMINAL_OUTPUT="console"
GRUB_CMDLINE_LINUX="crashkernel=auto rd.auto consoleblank=0 selinux=1 enforcing=0"
GRUB_CMDLINE_LINUX_DEFAULT=""
GRUB_DISABLE_RECOVERY="false"

EOF

#sed -i -e "s|^GRUB_TIMEOUT=.*$|GRUB_TIMEOUT=1|" /etc/default/grub
#sed -i -e "/GRUB_DEFAULT/ s|=.*$|=saved|" /etc/default/grub
#echo "GRUB_SAVEDEFAULT=true" >> /etc/default/grub
#echo "#GRUB_CMDLINE_LINUX='cryptdevice=/dev/sda2:cryptroot'" >> /etc/default/grub
echo 'GRUB_PRELOAD_MODULES="zfs"' >> /etc/default/grub
sed -i '/GRUB_CMDLINE_LINUX_DEFAULT/ s|="\(.*\)"|="\1 text xdriver=vesa nomodeset root=ZFS=${ZPOOLNM}/ROOT/default rootdelay=5"|'  \
  /etc/default/grub
grub2-mkconfig -o /boot/efi/EFI/\${ID}/grub.cfg
cp -f /boot/efi/EFI/\${ID}/grub.cfg /boot/grub2/grub.cfg
cp -f /boot/efi/EFI/\${ID}/grub.cfg /boot/efi/EFI/BOOT/grub.cfg


echo "Config SELinux" ; sleep 3
touch /.autorelabel
sed -i 's|SELINUX=.*$|SELINUX=permissive|' /etc/sysconfig/selinux
sestatus ; sleep 5

efibootmgr -c -d /dev/$DEVX -p \$(lsblk -nlpo name,label,partlabel | sed -n '/ESP/ s|.*[sv]da\([0-9]*\).*|\1|p') -l "/EFI/\${ID}/grubx64.efi" -L \${ID}
efibootmgr -c -d /dev/$DEVX -p \$(lsblk -nlpo name,label,partlabel | sed -n '/ESP/ s|.*[sv]da\([0-9]*\).*|\1|p') -l "/EFI/BOOT/BOOTX64.EFI" -L Default
efibootmgr -v ; sleep 3


# install/enable ssh just before finish
${DNFCMD} -y install openssh-clients openssh-server

dnf -y clean all
zpool trim ${ZPOOLNM} ; zpool set autotrim=on ${ZPOOLNM}
sync

exit

EOFchroot
# end chroot commands

tar -xf /tmp/init.tar -C /mnt/root/ ; sleep 5

read -p "Enter 'y' if ready to unmount & reboot [yN]: " response
if [ "y" = "$response" ] || [ "Y" = "$response" ] ; then
  sync ; swapoff -va ; umount -vR /mnt ; zfs umount -a ; zpool export -a ;
  reboot ; #poweroff ;
fi
