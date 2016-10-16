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
export DEVX=${DEVX:-sda}
ADD_VAGRANTUSER=${ADD_VAGRANTUSER:-0}

#export PLAIN_PASSWD=${1:-abcd0123}
export CRYPTED_PASSWD=${1:-\$6\$16CHARACTERSSALT\$o/XwaDmfuxBWVf1nEaH34MYX8YwFlAMo66n1.L3wvwdalv0IaV2b/ajr7xNcX/RFIPvfBNj.2Qxeh7v4JTjJ91}
export INIT_HOSTNAME=${2:-archlinux-boxv0000}

echo "Create/edit /etc/fstab" ; sleep 3
mkdir -p /mnt/etc
#genfstab -t LABEL -p /mnt >> /mnt/etc/fstab
genfstab -t UUID -p /mnt >> /mnt/etc/fstab


modprobe dm-mod ; modprobe dm-crypt ; lsmod | grep -e dm_mod -e dm_crypt
modprobe efivarfs

OS_ID=$(sed -n 's|^ID="*\(.*\)"*|\1|p' /etc/os-release)


# ip link ; dhcpcd #; iw dev
#if [[ ! -z wlan0 ]] ; then      # wlan_ifc: wlan0, wlp2s0
#    wifi-menu wlan0 ;
#fi

ifdev=$(ip -o link | grep 'link/ether' | grep 'LOWER_UP' | sed -n 's|\S*: \(\w*\):.*|\1|p')


echo "Config pkg repo mirror(s)" ; sleep 3
MULTILIB_LINENO=$(grep -n "\[multilib\]" /etc/pacman.conf | cut -f1 -d:)
sed -i "${MULTILIB_LINENO}s|^#||" /etc/pacman.conf
MULTILIB_LINENO=$(( $MULTILIB_LINENO + 1 ))
sed -i "${MULTILIB_LINENO}s|^#||" /etc/pacman.conf

pacman -Sy #; pacman -Sy pacman-contrib #reflector

cp -f /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak
LOCALE_COUNTRY=US
curl -s "https://www.archlinux.org/mirrorlist/?country=${LOCALE_COUNTRY}&use_mirror_status=on" | sed -e 's|^#Server|Server|' -e '/^#/d' | tee /etc/pacman.d/mirrorlist
#rankmirrors -vn 10 /etc/pacman.d/mirrorlist.bak | tee /etc/pacman.d/mirrorlist
#reflector --verbose --country $LOCALE_COUNTRY --sort rate --fastest 10 --save /etc/pacman.d/mirrorlist


echo "Bootstrap base pkgs" ; sleep 3
#pacman -Sg base | cut -d' ' -f2 | sed 's|^linux$|linux-lts|g' | pacstrap /mnt -
pacstrap /mnt $(pacman -Sqg base | sed 's|^linux$|&-lts|') base linux-lts linux-firmware cryptsetup device-mapper dhcpcd diffutils dosfstools e2fsprogs inetutils jfsutils less logrotate lvm2 man-db man-pages mdadm nano netctl perl reiserfsprogs s-nail sysfsutils texinfo usbutils vi which xfsprogs dialog grub openssh sudo intel-ucode amd-ucode efibootmgr linux-lts-headers
# ifplugd # wpa_actiond iw wireless_tools

cp /etc/pacman.conf /mnt/etc/pacman.conf
cp /etc/pacman.d/mirrorlist* /mnt/etc/pacman.d/


cat << EOFchroot | LANG=en_US.UTF-8 LANGUAGE=en arch-chroot /mnt /bin/sh
set -x

ls /proc ; sleep 5 ; ls /dev ; sleep 5


cat /etc/pacman.d/mirrorlist ; sleep 5
cat /etc/pacman.conf ; sleep 5

#pacman --noconfirm --needed -S lxde

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
echo -e "127.0.1.1\t${INIT_HOSTNAME}.localdomain\t${INIT_HOSTNAME}" >> /etc/hosts

#mkdir -p /etc/systemd/network
#sh -c 'cat > /etc/systemd/network/80-wired-dhcp.network' << EOF
#[Match]
#Name=en*
#
#[Network]
#DHCP=yes
#EOF


echo "Update services" ; sleep 3
## IP address config options: systemd-networkd, dhcpcd, dhclient, netctl
#systemctl enable systemd-networkd.service

systemctl enable dhcpcd@${ifdev}.service # dhcpcd.service

#systemctl enable dhclient@${ifdev}.service
#systemctl start dhclient@${ifdev}.service

#cp /etc/netctl/examples/ethernet-dhcp /etc/netctl/basic_dhcp_profile
#systemctl enable netctl-ifplugd@${ifdev}.service # netctl-auto@${ifdev}.service

systemctl enable sshd.service #; systemctl enable sshd.socket


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


sh -c 'cat >> /etc/ssh/sshd_config' << EOF
TrustedUserCAKeys /etc/ssh/sshca-id_ed25519.pub
RevokedKeys /etc/ssh/krl.krl
#HostCertificate /etc/ssh/ssh_host_ed25519_key-cert.pub
#HostCertificate /etc/ssh/ssh_host_ecdsa_key-cert.pub
#HostCertificate /etc/ssh/ssh_host_rsa_key-cert.pub

EOF


echo "Customize initial ramdisk (hooks: lvm)" ; sleep 3
#sed -i '/^HOOK/ s|filesystems|encrypt lvm2 filesystems|' /etc/mkinitcpio.conf	# encrypt hook only if crypted root partition
sed -i '/^HOOK/ s|filesystems|lvm2 filesystems|' /etc/mkinitcpio.conf
mkinitcpio -p linux-lts ; mkinitcpio -P


echo "Bootloader installation & config" ; sleep 3
mkdir -p /boot/efi/EFI/archlinux /boot/efi/EFI/BOOT
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=archlinux --recheck --removable
grub-install --target=i386-pc --recheck /dev/$DEVX
cp /boot/efi/EFI/archlinux/grubx64.efi /boot/efi/EFI/BOOT/BOOTX64.EFI

#sed -i -e "s|^GRUB_TIMEOUT=.*$|GRUB_TIMEOUT=1|" /etc/default/grub
sed -i -e '/GRUB_CMDLINE_LINUX_DEFAULT/ s|="\(.*\)"|="\1 text xdriver=vesa nomodeset rootdelay=5"|' /etc/default/grub
#sed -i -e '/GRUB_CMDLINE_LINUX_DEFAULT/ s|="\(.*\)"|="\1 video=1024x768 "|' /etc/default/grub
echo 'GRUB_PRELOAD_MODULES="lvm"' >> /etc/default/grub
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
efibootmgr -c -d /dev/$DEVX -p $IDX_ESP -l '\EFI\archlinux\grubx64.efi' -L ArchLinux
efibootmgr -c -d /dev/$DEVX -p $IDX_ESP -l '\EFI\BOOT\BOOTX64.EFI' -L Default

sync ; swapoff -va ; umount -vR /mnt
reboot #poweroff
