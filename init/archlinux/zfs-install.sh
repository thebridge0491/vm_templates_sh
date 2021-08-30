#!/bin/sh -x

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

export INIT_HOSTNAME=${1:-artix-boxv0000}
#export PLAIN_PASSWD=${2:-abcd0123}
export CRYPTED_PASSWD=${2:-\$6\$16CHARACTERSSALT\$o/XwaDmfuxBWVf1nEaH34MYX8YwFlAMo66n1.L3wvwdalv0IaV2b/ajr7xNcX/RFIPvfBNj.2Qxeh7v4JTjJ91}

echo "Create /etc/fstab" ; sleep 3
mkdir -p /mnt/etc /mnt/media ; chmod 0755 /mnt/media
#if command -v genfstab > /dev/null ; then
#  genfstab -t LABEL -p /mnt > /mnt/etc/fstab ; # not zfs filesys
#elif command -v fstabgen > /dev/null ; then
#  fstabgen -t LABEL -p /mnt > /mnt/etc/fstab ; # not zfs filesys
#fi
cat << EOF > /mnt/etc/fstab
LABEL=${GRP_NM}-osBoot   /boot       ext2    defaults    0   2
LABEL=ESP      /boot/efi   vfat    umask=0077  0   2
LABEL=${GRP_NM}-osSwap   none        swap    sw          0   0

proc                            /proc       proc    defaults    0   0
sysfs                           /sys        sysfs   defaults    0   0

EOF

# ip link ; dhcpcd #; iw dev
#if [[ ! -z wlan0 ]] ; then      # wlan_ifc: wlan0, wlp2s0
#    wifi-menu wlan0 ;
#fi


echo "Config pkg repo mirror(s)" ; sleep 3
mkdir -p /mnt/etc/pacman.d /mnt/var/lib/pacman
if [ -f /etc/pacman.conf ] && [ -d /etc/pacman.d ] ; then
  cp /etc/pacman.conf /mnt/etc/pacman.conf ;
  cp /etc/pacman.d/mirrorlist* /mnt/etc/pacman.d/ ;
else
  mkdir -p /mnt/etc/pacman.d /mnt/var/lib/pacman ;
  #(cd $(dirname $0) ; cat etc_pacman.conf-arch > /etc/pacman.conf) ;
  curl -s "https://gitea.artixlinux.org/packagesP/pacman/raw/branch/master/trunk/pacman.conf" | tee /etc/pacman.conf ;
  cp /etc/pacman.conf /mnt/etc/pacman.conf ;
fi
## fetch cmd: [curl -s | wget -qO -]
#reflector --verbose --country ${LOCALE_COUNTRY:-US} --sort rate --fastest 10 --save /etc/pacman.d/mirrorlist-arch
curl -s "https://archlinux.org/mirrorlist/?country=${LOCALE_COUNTRY:-US}&use_mirror_status=on" | sed -e 's|^#Server|Server|' -e '/^#/d' | tee /etc/pacman.d/mirrorlist-arch
curl -s "https://gitea.artixlinux.org/packagesA/artix-mirrorlist/raw/branch/master/trunk/mirrorlist" | tee /etc/pacman.d/mirrorlist-artix
cp /etc/pacman.d/mirrorlist-artix /etc/pacman.d/mirrorlist

#cp /etc/pacman.d/mirrorlist-arch /etc/pacman.d/mirrorlist-arch.bak
#rankmirrors -vn 10 /etc/pacman.d/mirrorlist-arch.bak | tee /etc/pacman.d/mirrorlist-arch

sleep 5 ; cp /mnt/etc/pacman.conf /mnt/etc/pacman.conf.old
cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist-artix /etc/pacman.d/mirror-arch /mnt/etc/pacman.d/
for libname in multilib lib32 ; do
  MULTILIB_LINENO=$(grep -n "\[$libname\]" /mnt/etc/pacman.conf | cut -f1 -d:) ;
  if [ "" = "${MULTILIB_LINENO}" ] ; then continue ; fi ;
  sed -i "${MULTILIB_LINENO}s|^#||" /mnt/etc/pacman.conf ;
  MULTILIB_LINENO=$(( $MULTILIB_LINENO + 1 )) ;
  sed -i "${MULTILIB_LINENO}s|^#||" /mnt/etc/pacman.conf ;
done


## init [artix | archlinux] pacman keyring
pacman-key --init ; pacman-key --populate artix
pacman-key --recv-keys 'arch@eworm.de' ; pacman-key --lsign-key 498E9CEE
pacman -Sy --noconfirm artix-keyring


echo "Bootstrap base pkgs" ; sleep 3
zfs umount $ZPOOLNM/var/mail ; zfs destroy $ZPOOLNM/var/mail
pkg_list="base base-devel intel-ucode amd-ucode linux-firmware dosfstools e2fsprogs xfsprogs reiserfsprogs jfsutils sysfsutils grub efibootmgr usbutils inetutils logrotate which dialog man-db man-pages less perl s-nail texinfo diffutils vi nano sudo"
# ifplugd # wpa_actiond iw wireless_tools
#pacman -Sg base | cut -d' ' -f2 | sed 's|^linux$|linux-lts|g' | pacstrap /mnt -
if command -v pacstrap > /dev/null ; then
  pacstrap /mnt $(pacman -Sqg base | sed 's|^linux$|&-lts|') $pkg_list ;
elif command -v basestrap > /dev/null ; then
  basestrap /mnt $(pacman -Sqg base | sed 's|^linux$|&-lts|') $pkg_list ;
else
  pacman --root /mnt -Sy $pkg_list ;
fi

echo "Prepare chroot (mount --[r]bind devices)" ; sleep 3
#if command -v arch-chroot > /dev/null ; then
#  CHROOT_CMD=arch-chroot ;
#elif command -v artools-chroot > /dev/null ; then
#  CHROOT_CMD=artools-chroot ;
#fi
CHROOT_CMD=chroot
#cp /etc/mtab /mnt/etc/mtab
mkdir -p /mnt/dev /mnt/proc /mnt/sys /mnt/run
mount --rbind /proc /mnt/proc ; mount --rbind /sys /mnt/sys
mount --rbind /dev /mnt/dev

mount --rbind /dev/pts /mnt/dev/pts ; mount --rbind /run /mnt/run
modprobe efivarfs
mount -t efivarfs efivarfs /mnt/sys/firmware/efi/efivars/


cp /etc/resolv.conf /mnt/etc/resolv.conf
cp /tmp/archzfs.gpg /tmp/init/archlinux/repo_archzfs.cfg /mnt/tmp/
cp /etc/zfs/zpool.cache /mnt/etc/zfs/


cat << EOFchroot | LANG=en_US.UTF-8 LANGUAGE=en $CHROOT_CMD /mnt /bin/sh
set -x

chmod 1777 /tmp ; chmod 1777 /var/tmp

unset LC_ALL
export TERM=xterm-color     # xterm | xterm-color
#hostname ${INIT_HOSTNAME}

ls /proc ; sleep 5 ; ls /dev ; sleep 5

if [ -f /etc/os-release ] ; then
  . /etc/os-release ;
elif [ -f /usr/lib/os-release ] ; then
  . /usr/lib/os-release ;
fi
if [ "arch" = "\${ID}" ] ; then
  cp /etc/pacman.d/mirrorlist-arch /etc/pacman.d/mirrorlist ;
elif [ "artix" = "\${ID}" ] ; then
  cp /etc/pacman.d/mirrorlist-artix /etc/pacman.d/mirrorlist ;
fi
cat /etc/pacman.conf ; sleep 5

pacman-key --init
if [ "arch" = "\${ID}" ] ; then
  pacman-key --populate archlinux ;
  pacman-key --recv-keys 'arch@eworm.de' ; pacman-key --lsign-key 498E9CEE ;
  pacman --noconfirm -Sy archlinux-keyring ;
elif [ "artix" = "\${ID}" ] ; then
  pacman-key --populate artix ;
  pacman-key --recv-keys 'arch@eworm.de' ; pacman-key --lsign-key 498E9CEE ;
  pacman --noconfirm -Sy artix-keyring ;
fi
if [ "arch" = "\${ID}" ] ; then
  pacman --noconfirm --needed -S linux-lts linux-lts-headers cryptsetup device-mapper mdadm dhcpcd openssh ;
elif [ "artix" = "\${ID}" ] ; then
  pacman --noconfirm --needed -S linux-lts linux-lts-headers cryptsetup-openrc device-mapper-openrc mdadm-openrc dhcpcd-openrc openssh-openrc ;
fi
#pacman --noconfirm --needed -S xfce4


curl -o /tmp/archzfs.gpg https://archzfs.com/archzfs.gpg
cat /tmp/repo_archzfs.cfg >> /etc/pacman.conf
pacman-key --add /tmp/archzfs.gpg ; pacman-key --lsign-key F75D9D76
pacman -Sy

pacman --noconfirm -Sy zfs-dkms # archzfs-linux-lts
echo REMAKE_INITRD=yes > /etc/dkms/zfs.conf
sh -c 'cat >> /etc/modules-load.d/zfs.conf' << EOF
# load zfs.ko at boot
zfs

EOF
modprobe zfs ; zpool version ; sleep 5
#pacman --noconfirm -Sy zfs-linux-lts zfs-utils


echo "Config keyboard ; localization" ; sleep 3
kbd_mode -u ; loadkeys us
sed -i -e '/en_US.UTF-8 UTF-8/ s|^# ||' /etc/locale.gen
echo 'LANG=en_US.UTF-8' > /etc/locale.conf
locale-gen


echo "Config time zone & clock" ; sleep 3
ln -sf /usr/share/zoneinfo/UTC /etc/localtime
hwclock --systohc --utc


echo "Config hostname ; network" ; sleep 3
echo "${INIT_HOSTNAME}" > /etc/hostname
resolvconf -u   # generates /etc/resolv.conf
cat /etc/resolv.conf ; sleep 5
sed -i '/127.0.1.1/d' /etc/hosts
echo "127.0.1.1		${INIT_HOSTNAME}.localdomain	${INIT_HOSTNAME}" >> /etc/hosts

ifdev=\$(ip -o link | grep 'link/ether' | grep 'LOWER_UP' | sed -n 's|\S*: \(\w*\):.*|\1|p')
#mkdir -p /etc/systemd/network
#sh -c 'cat > /etc/systemd/network/80-wired-dhcp.network' << EOF
#[Match]
#Name=en*
#
#[Network]
#DHCP=yes
#EOF


echo "Update services" ; sleep 3
if command -v systemctl > /dev/null ; then
  ## IP address config options: systemd-networkd, dhcpcd, dhclient, netctl
  #systemctl enable systemd-networkd.service ;

  systemctl enable dhcpcd@\${ifdev}.service ; # dhcpcd.service

  #systemctl enable dhclient@\${ifdev}.service ;
  #systemctl start dhclient@\${ifdev}.service ;

  #cp /etc/netctl/examples/ethernet-dhcp /etc/netctl/basic_dhcp_profile ;
  #systemctl enable netctl-ifplugd@\${ifdev}.service # netctl-auto@\${ifdev}.service ;

  systemctl enable sshd.service #; systemctl enable sshd.socket ;

  systemctl enable zfs-import-cache ; systemctl enable zfs-import.target ;
  systemctl enable zfs-mount ; systemctl enable zfs.target ;
elif command -v rc-update > /dev/null ; then
  ## IP address config options: dhcpcd, dhclient
  rc-update add dhcpcd default ;

  #rc-update add dhclient default ;
  #rc-service dhclient start ;

  rc-update add sshd default ;

  cat << EOF >> /etc/init.d/zfs ;
#!/sbin/openrc-run

command="zfs mount $ZPOOLNM/ROOT/default ; zfs mount -a"

EOF

  chmod +x /etc/init.d/zfs ;
  rc-update add zfs default ;
fi


echo "Set root passwd ; add user" ; sleep 3
#echo -n "root:${PLAIN_PASSWD}" | chpasswd
echo -n 'root:${CRYPTED_PASSWD}' | chpasswd -e

#DIR_MODE=0750
useradd -g users -m -G wheel -s /bin/bash -c 'Packer User' packer
#echo -n "packer:${PLAIN_PASSWD}" | chpasswd
echo -n 'packer:${CRYPTED_PASSWD}' | chpasswd -e
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


grub-probe /boot

echo "Customize initial ramdisk (hooks: zfs)" ; sleep 3
sed -i '/^HOOK/ s| keyboard||' /etc/mkinitcpio.conf
#sed -i '/^HOOK/ s|filesystems|encrypt zfs usr filesystems|' /etc/mkinitcpio.conf	# encrypt hook only if crypted root partition
sed -i '/^HOOK/ s|filesystems|keyboard zfs usr filesystems|' /etc/mkinitcpio.conf
mkinitcpio -p linux-lts ; mkinitcpio -P

echo "Hold zfs & kernel package upgrades (require manual upgrade)"
sed -i 's|#IgnorePkg|IgnorePkg|' /etc/pacman.conf
for pkgX in zfs-dkms zfs-utils linux-lts linux-lts-headers ; do
  sed -i "/^IgnorePkg/ s|\$| \${pkgX}|" /etc/pacman.conf
done
grep -e '^IgnorePkg' /etc/pacman.conf ; sleep 3


echo "Bootloader installation & config" ; sleep 3
mkdir -p /boot/efi/EFI/\${ID} /boot/efi/EFI/BOOT
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=\${ID} --recheck --removable
grub-install --target=i386-pc --recheck /dev/$DEVX
cp /boot/efi/EFI/\${ID}/grubx64.efi /boot/efi/EFI/BOOT/BOOTX64.EFI

#sed -i -e "s|^GRUB_TIMEOUT=.*$|GRUB_TIMEOUT=1|" /etc/default/grub
sed -i -e '/GRUB_CMDLINE_LINUX_DEFAULT/ s|="\(.*\)"|="\1 text xdriver=vesa nomodeset zfs=${ZPOOLNM}/ROOT/default rootdelay=10"|' /etc/default/grub
#sed -i -e '/GRUB_CMDLINE_LINUX_DEFAULT/ s|="\(.*\)"|="\1 video=1024x768 "|' /etc/default/grub
echo 'GRUB_PRELOAD_MODULES="zfs"' >> /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

efibootmgr -c -d /dev/$DEVX -p \$(lsblk -nlpo name,label,partlabel | sed -n '/ESP/ s|.*[sv]da\([0-9]*\).*|\1|p') -l "/EFI/\${ID}/grubx64.efi" -L \${ID}
efibootmgr -c -d /dev/$DEVX -p \$(lsblk -nlpo name,label,partlabel | sed -n '/ESP/ s|.*[sv]da\([0-9]*\).*|\1|p') -l "/EFI/BOOT/BOOTX64.EFI" -L Default
efibootmgr -v ; sleep 3


pacman --noconfirm -Sc
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
