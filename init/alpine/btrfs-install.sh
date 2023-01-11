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
export DEVX=${DEVX:-sda} ; export GRP_NM=${GRP_NM:-vg0}
export MIRROR=${MIRROR:-dl-cdn.alpinelinux.org/alpine} ; UNAME_M=$(uname -m)
RELEASE=${RELEASE:-latest-stable}

export INIT_HOSTNAME=${1:-alpine-boxv0000}
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


# ip link ; udhcpc -i eth0 #; iw dev

#ifdev=$(ip -o link | grep 'link/ether' | grep 'LOWER_UP' | sed -n 's|\S*: \(\w*\):.*|\1|p')


echo "Bootstrap base pkgs" ; sleep 3
if command -v apk > /dev/null ; then
  apk --arch ${UNAME_M} --repository http://${MIRROR}/${RELEASE}/main --update-cache --allow-untrusted --root /mnt --initdb add alpine-base tzdata ;
else
  curl -LO http://dl-cdn.alpinelinux.org/alpine/latest-stable/main/${UNAME_M}/apk-tools-static-${apktools_ver:-2.12.10-r1}.apk ;
  tar -xf apk-tools-static-*.apk ;
  ./sbin/apk.static --arch ${UNAME_M} --repository http://${MIRROR}/${RELEASE}/main --update-cache --allow-untrusted --root /mnt --initdb add alpine-base tzdata ;
fi


echo "Prepare chroot (mount --[r]bind devices)" ; sleep 3
cp /etc/mtab /mnt/etc/mtab
mkdir -p /mnt/dev /mnt/proc /mnt/sys /mnt/run
mount --rbind /proc /mnt/proc ; mount --rbind /sys /mnt/sys
mount --rbind /dev /mnt/dev

mount --rbind /dev/pts /mnt/dev/pts ; mount --rbind /run /mnt/run
modprobe efivarfs
mount -t efivarfs efivarfs /mnt/sys/firmware/efi/efivars/


cp /etc/resolv.conf /mnt/etc/resolv.conf ; mkdir -p /mnt/root
mkdir -p /mnt/etc/apk ; cp /etc/apk/repositories /mnt/etc/apk/


cat << EOFchroot | LANG=en_US.UTF-8 LANGUAGE=en chroot /mnt /bin/sh
set -x

chmod 1777 /tmp ; chmod 1777 /var/tmp
chown root:root / ; chmod 0755 /

unset LC_ALL
export TERM=xterm-color     # xterm | xterm-color
#hostname ${INIT_HOSTNAME}

ls /proc ; sleep 5 ; ls /dev ; sleep 5


. /etc/os-release
#RELEASE=\$(cat /etc/alpine-release | cut -d. -f1-2)
sed -i '/cdrom/ s|^|#|' /etc/apk/repositories
#echo "http://${MIRROR}/v\${RELEASE}/main" >> /etc/apk/repositories
echo "http://${MIRROR}/${RELEASE}/main" >> /etc/apk/repositories
echo "http://${MIRROR}/${RELEASE}/community" >> /etc/apk/repositories
apk --arch ${UNAME_M} update
cat /etc/apk/repositories ; sleep 5


echo "Add software package selection(s)" ; sleep 3
apk --arch ${UNAME_M} add tzdata sudo linux-lts linux-lts-dev dosfstools e2fsprogs xfsprogs mkinitfs dhcp bash util-linux shadow openssh grub-efi efibootmgr multipath-tools cryptsetup btrfs-progs
#apk --arch ${UNAME_M} add xfce4
if [ "x86_64" = "${UNAME_M}" ] ; then
  apk --arch ${UNAME_M} add grub-bios
fi
sleep 5

modprobe btrfs


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
echo "127.0.1.1    ${INIT_HOSTNAME}.localdomain    ${INIT_HOSTNAME}" >> /etc/hosts

ifdev=\$(ip -o link | grep 'link/ether' | grep 'LOWER_UP' | sed -n 's|\S*: \(\w*\):.*|\1|p')

sh -c 'cat > /etc/network/interfaces' << EOF
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp

EOF


echo "Update services" ; sleep 3
cat << EOF >> /etc/init.d/btrfs-scan
#!/sbin/openrc-run

name="btrfs-scan"

depend() {
  before localmount
}

start() {
  /sbin/btrfs device scan
}

EOF

chmod +x /etc/init.d/btrfs-scan

for svc_runlvl in devfs:sysinit dmesg:sysinit mdev:sysinit hwdrivers:sysinit \
		networking:boot urandom:boot hostname:boot hwclock:boot modules:boot \
		sysctl:boot bootmisc:boot syslog:boot swap:boot loadkmap:boot \
		mount-ro:shutdown killprocs:shutdown savecache:shutdown \
		acpid:default sshd:default crond:default btrfs-scan:boot ; do
		# udev:sysinit udev-postmount:default udev-trigger:sysinit ; do
	svc=\$(echo \$svc_runlvl | cut -d: -f1) ;
	runlvl=\$(echo \$svc_runlvl | cut -d: -f2) ;

	rc-update add \$svc \$runlvl ;
done


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
sleep 5


sed -i "/^%wheel.*(ALL)\s*ALL/ s|%wheel|# %wheel|" /etc/sudoers
sed -i "/^#.*%wheel.*NOPASSWD.*/ s|^#.*%wheel|%wheel|" /etc/sudoers
sed -i "s|^[^#].*requiretty|# Defaults requiretty|" /etc/sudoers


#echo "Temporarily permit root login via ssh password" ; sleep 3
#sed -i "/PermitRootLogin/ s|^\(.*\)$|PermitRootLogin yes|" /etc/ssh/sshd_config


echo "Config Linux kernel"
features="ata base cdrom ext4 xfs keymap kms mmc raid scsi usb virtio btrfs network"
echo features=\""\${features}"\" > /etc/mkinitfs/mkinitfs.conf
kernel="\$(ls -A /lib/modules/ | tail -1)"
mkinitfs "\${kernel}"


grub-probe /boot

echo "Bootloader installation & config" ; sleep 3
mkdir -p /boot/efi/EFI/\${ID} /boot/efi/EFI/BOOT
if [ "aarch64" = "${UNAME_M}" ] ; then
  grub-install --target=arm64-efi --efi-directory=/boot/efi --bootloader-id=\${ID} --recheck --removable ;
  cp /boot/efi/EFI/\${ID}/grubaa64.efi /boot/efi/EFI/BOOT/BOOTAA64.EFI ;
else
  grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=\${ID} --recheck --removable ;
  grub-install --target=i386-pc --recheck /dev/$DEVX ;
  cp /boot/efi/EFI/\${ID}/grubx64.efi /boot/efi/EFI/BOOT/BOOTX64.EFI ;
fi

#sed -i -e "s|^GRUB_TIMEOUT=.*$|GRUB_TIMEOUT=1|" /etc/default/grub
#sed -i -e '/GRUB_CMDLINE_LINUX_DEFAULT/ s|="\(.*\)"|="\1 rd.auto=1 text xdriver=vesa nomodeset rootdelay=5 modules=sd-mod,usb-storage,ext4,btrfs"|' /etc/default/grub
#sed -i -e '/GRUB_CMDLINE_LINUX_DEFAULT/ s|="\(.*\)"|="\1 video=1024x768 "|' /etc/default/grub
echo 'GRUB_CMDLINE_LINUX_DEFAULT="rd.auto=1 text nomodeset rootdelay=5 modules=sd-mod,usb-storage,ext4,btrfs"' >> /etc/default/grub
echo 'GRUB_PRELOAD_MODULES="btrfs"' >> /etc/default/grub
if [ "\$(dmesg | grep -ie 'Hypervisor detected')" ] ; then
  sed -i -e '/GRUB_CMDLINE_LINUX_DEFAULT/ s|="\(.*\)"|="\1 net.ifnames=0 biosdevname=0"|' /etc/default/grub ;
fi
grub-mkconfig -o /boot/grub/grub.cfg

if [ "aarch64" = "${UNAME_M}" ] ; then
  efibootmgr -c -d /dev/$DEVX -p \$(lsblk -nlpo name,label,partlabel | sed -n '/ESP/ s|.*[sv]da\([0-9]*\).*|\1|p') -l "/EFI/\${ID}/grubaa64.efi" -L \${ID}
  efibootmgr -c -d /dev/$DEVX -p \$(lsblk -nlpo name,label,partlabel | sed -n '/ESP/ s|.*[sv]da\([0-9]*\).*|\1|p') -l "/EFI/BOOT/BOOTAA64.EFI" -L Default
else
  efibootmgr -c -d /dev/$DEVX -p \$(lsblk -nlpo name,label,partlabel | sed -n '/ESP/ s|.*[sv]da\([0-9]*\).*|\1|p') -l "/EFI/\${ID}/grubx64.efi" -L \${ID}
  efibootmgr -c -d /dev/$DEVX -p \$(lsblk -nlpo name,label,partlabel | sed -n '/ESP/ s|.*[sv]da\([0-9]*\).*|\1|p') -l "/EFI/BOOT/BOOTX64.EFI" -L Default
fi
efibootmgr -v ; sleep 3


apk --arch ${UNAME_M} -v cache clean
fstrim -av
sync

exit

EOFchroot
# end chroot commands

tar -xf /tmp/scripts.tar -C /mnt/root/ ; sleep 5

read -p "Enter 'y' if ready to unmount & reboot [yN]: " response
if [ "y" = "$response" ] || [ "Y" = "$response" ] ; then
  sync ; swapoff -va ; umount -vR /mnt ;
  reboot ; #poweroff ;
fi
