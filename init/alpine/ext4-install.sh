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
export MIRROR=${MIRROR:-mirror.math.princeton.edu/pub/alpinelinux}
ADD_VAGRANTUSER=${ADD_VAGRANTUSER:-0}

#export PLAIN_PASSWD=${1:-abcd0123}
export CRYPTED_PASSWD=${1:-\$6\$16CHARACTERSSALT\$o/XwaDmfuxBWVf1nEaH34MYX8YwFlAMo66n1.L3wvwdalv0IaV2b/ajr7xNcX/RFIPvfBNj.2Qxeh7v4JTjJ91}
export INIT_HOSTNAME=${2:-alpine-boxv0000}

#rc-service sshd stop
service sshd stop


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


OS_ID=$(sed -n 's|^ID="*\(.*\)"*|\1|p' /etc/os-release)
RELEASE=$(cat /etc/alpine-release | cut -d. -f1-2)

apk update
#apk add efibootmgr

modprobe dm-mod ; modprobe dm-crypt ; lsmod | grep -e dm_mod -e dm_crypt
modprobe efivarfs

# ip link ; udhcpc -i eth0 #; iw dev
#if [[ ! -z wlan0 ]] ; then      # wlan_ifc: wlan0, wlp2s0
#    wifi-menu wlan0 ;
#fi

ifdev=$(ip -o link | grep 'link/ether' | grep 'LOWER_UP' | sed -n 's|\S*: \(\w*\):.*|\1|p')


echo "Bootstrap base pkgs" ; sleep 3
apk fetch apk-tools-static ; tar -xzf ./apk-tools-static-*.apk
#./sbin/apk.static --repository http://${MIRROR}/v${RELEASE}/main --update-cache --allow-untrusted --root /mnt --initdb add alpine-base tzdata sudo
./sbin/apk.static --repository http://${MIRROR}/latest-stable/main --update-cache --allow-untrusted --root /mnt --initdb add alpine-base tzdata sudo


cp /etc/resolv.conf /mnt/etc/resolv.conf ; mkdir -p /mnt/root
cp /etc/apk/repositories /mnt/etc/apk

echo "Prepare chroot (mount --bind devices)" ; sleep 3
cp /etc/mtab /mnt/etc/mtab
mkdir -p /mnt/dev /mnt/proc /mnt/sys /mnt/hostlvm /mnt/hostudev /mnt/run
mount --bind /proc /mnt/proc ; mount --bind /sys /mnt/sys
mount --bind /dev /mnt/dev ; mount -t devpts none /mnt/dev/pts
#mount --bind /dev /mnt/dev ; mount --bind /dev/pts /mnt/dev/pts

mount -t efivarfs efivarfs /mnt/sys/firmware/efi/efivars/
mount --bind /run/lvm /mnt/hostlvm ; mount --bind /run/udev /mnt/hostudev


cat << EOFchroot | LANG=en_US.UTF-8 LANGUAGE=en chroot /mnt /bin/sh
set -x

chown root:root / ; chmod 0755 /

unset LC_ALL
export TERM=xterm-color     # xterm | xterm-color

ls /proc ; sleep 5 ; ls /dev ; sleep 5


mkdir -p /etc/apk
#echo "http://${MIRROR}/v${RELEASE}/main" >> /etc/apk/repositories
sed -i '/cdrom/ s|^|#|' /etc/apk/repositories
echo "http://${MIRROR}/latest-stable/main" >> /etc/apk/repositories
echo "http://${MIRROR}/latest-stable/community" >> /etc/apk/repositories
apk update
cat /etc/apk/repositories ; sleep 5

echo "Add software package selection(s)" ; sleep 3
apk add tzdata sudo linux-vanilla dosfstools e2fsprogs mkinitfs dhcp bash util-linux shadow grub-bios grub-efi cryptsetup lvm2 openssh # efibootmgr multipath-tools
#apk add xfce4
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
sed -i '/127.0.1.1/d' /etc/hosts
echo -e "127.0.1.1\t${INIT_HOSTNAME}.localdomain\t${INIT_HOSTNAME}" >> /etc/hosts

sh -c 'cat > /etc/network/interfaces' << EOF
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp

EOF


echo "Update services" ; sleep 3
for svc_runlvl in devfs:sysinit dmesg:sysinit mdev:sysinit hwdrivers:sysinit \
		networking:boot urandom:boot hostname:boot hwclock:boot modules:boot \
		sysctl:boot bootmisc:boot syslog:boot swap:boot lvm:boot \
		loadkmap:boot mount-ro:shutdown killprocs:shutdown savecache:shutdown \
		acpid:default sshd:default crond:default ; do
		# udev:sysinit udev-postmount:default udev-trigger:sysinit ; do
	svc=\$(echo \$svc_runlvl | cut -d: -f1) ;
	runlvl=\$(echo \$svc_runlvl | cut -d: -f2) ;
	
	rc-update add \$svc \$runlvl ;
done


echo "Set root passwd ; add user" ; sleep 3
#echo -n "root:${PLAIN_PASSWD}" | chpasswd
echo -n 'root:${CRYPTED_PASSWD}' | chpasswd -e

#DIR_MODE=0750 
useradd -m -g users -G wheel -s /bin/bash -c 'Packer User' packer
#echo -n "packer:${PLAIN_PASSWD}" | chpasswd
echo -n 'packer:${CRYPTED_PASSWD}' | chpasswd -e
chown -R packer:\$(id -gn packer) /home/packer

#sh -c 'cat > /etc/sudoers.d/99_packer' << EOF
#Defaults:packer !requiretty
#\$(id -un packer) ALL=(ALL) NOPASSWD: ALL
#
#EOF
#chmod 0440 /etc/sudoers.d/99_packer
sleep 5


if [ ! "0" = "${ADD_VAGRANTUSER}" ] ; then
#DIR_MODE=0750 
useradd -g users -m -G wheel -s /bin/bash -c 'Vagrant User' vagrant ;
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
sed -i "s|^[^#].*requiretty|# Defaults requiretty|" /etc/sudoers


echo "Temporarily permit root login via ssh password" ; sleep 3
sed -i "/PermitRootLogin/ s|^\(.*\)$|PermitRootLogin yes|" /etc/ssh/sshd_config

sh -c 'cat >> /etc/ssh/sshd_config' << EOF
TrustedUserCAKeys /etc/ssh/sshca-id_ed25519.pub
RevokedKeys /etc/ssh/krl.krl
#HostCertificate /etc/ssh/ssh_host_ed25519_key-cert.pub
#HostCertificate /etc/ssh/ssh_host_ecdsa_key-cert.pub
#HostCertificate /etc/ssh/ssh_host_rsa_key-cert.pub

EOF


echo "Bootloader installation & config" ; sleep 3
mkdir -p /boot/efi/EFI/alpine /boot/efi/EFI/BOOT
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=alpine --recheck --removable
grub-install --target=i386-pc --recheck /dev/$DEVX
cp /boot/efi/EFI/alpine/grubx64.efi /boot/efi/EFI/BOOT/BOOTX64.EFI

#sed -i -e "s|^GRUB_TIMEOUT=.*$|GRUB_TIMEOUT=1|" /etc/default/grub
#sed -i -e '/GRUB_CMDLINE_LINUX_DEFAULT/ s|="\(.*\)"|="\1 rd.auto=1 text xdriver=vesa nomodeset rootdelay=5 modules=sd-mod,usb-storage,ext4,lvm"|' /etc/default/grub
#sed -i -e '/GRUB_CMDLINE_LINUX_DEFAULT/ s|="\(.*\)"|="\1 video=1024x768 "|' /etc/default/grub
echo 'GRUB_CMDLINE_LINUX_DEFAULT="rd.auto=1 text nomodeset rootdelay=5 modules=sd-mod,usb-storage,ext4,lvm"' >> /etc/default/grub
echo 'GRUB_PRELOAD_MODULES="lvm"' >> /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg


echo "Config Linux kernel"
features="ata base cdrom ext4 keymap kms mmc raid scsi usb virtio lvm network"
echo features=\""\${features}"\" > /etc/mkinitfs/mkinitfs.conf
kernel="\$(ls -A /lib/modules/ | tail -1)"
mkinitfs "\${kernel}"

exit

EOFchroot
# end chroot commands

for fileX in /tmp/disk_setup.sh /tmp/install.sh ; do
  cp $fileX /mnt/root/ ;
done
sync

#IDX_ESP=$(lsblk -nlpo name,label,partlabel | sed -n '/ESP/ s|.*[sv]da\([0-9]*\).*|\1|p')
#efibootmgr -v ; sleep 3
#efibootmgr -c -d /dev/$DEVX -p $IDX_ESP -l '\EFI\alpine\grubx64.efi' -L Alpine
#efibootmgr -c -d /dev/$DEVX -p $IDX_ESP -l '\EFI\BOOT\BOOTX64.EFI' -L Default

sync ; swapoff -va ; umount -vR /mnt
reboot #poweroff
