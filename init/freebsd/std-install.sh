#!/bin/sh -x

# nc -l [-p] {port} > file ## nc -w3 {host} {port} < file  # netcat xfr
# ssh user@ipaddr "sudo sh -xs - arg1 argN" < script.sh  # w/ sudo
# ssh user@ipaddr "su -m root -c 'sh -xs - arg1 argN'" < script.sh

#sh /tmp/disk_setup.sh gpart_vmdisk std
#sh /tmp/disk_setup.sh format_partitions std
#sh /tmp/disk_setup.sh mount_filesystems

# passwd crypted hash: [md5|sha256|sha512] - [$1|$5|$6]$...
# perl -e 'use Term::ReadKey ; print "Password:\n" ; ReadMode "noecho" ; $_=<STDIN> ; ReadMode "normal" ; chomp $_ ; print crypt($_, "\$6\$16CHARACTERSSALT") . "\n"'
# ruby -e "['io/console','digest/sha2'].each {|i| require i} ; puts 'Password:' ; puts STDIN.noecho(&:gets).chomp.crypt(\"\$6\$16CHARACTERSSALT\")"
# python -c "import crypt,getpass ; print(crypt.crypt(getpass.getpass(), \"\$6\$16CHARACTERSSALT\"))"

set -x
if [ -e /dev/vtbd0 ] ; then
  export DEVX=vtbd0 ;
elif [ -e /dev/ada0 ] ; then
  export DEVX=ada0 ;
elif [ -e /dev/da0 ] ; then
  export DEVX=da0 ;
fi

export GRP_NM=${GRP_NM:-bsd0}

export INIT_HOSTNAME=${1:-freebsd-boxv0000}
#export PLAIN_PASSWD=${2:-abcd0123}
export CRYPTED_PASSWD=${2:-\$6\$16CHARACTERSSALT\$o/XwaDmfuxBWVf1nEaH34MYX8YwFlAMo66n1.L3wvwdalv0IaV2b/ajr7xNcX/RFIPvfBNj.2Qxeh7v4JTjJ91}

tunefs -n enable -t enable /dev/gpt/${GRP_NM}-fsRoot
tunefs -n enable -t enable /dev/gpt/${GRP_NM}-fsVar
tunefs -n enable -t enable /dev/gpt/${GRP_NM}-fsHome

echo "Create /etc/fstab" ; sleep 3
mkdir -p /mnt/etc /mnt/compat/linux/proc
sh -c 'cat > /mnt/etc/fstab' << EOF
/dev/gpt/${GRP_NM}-fsSwap    none        swap    sw      0   0
/dev/gpt/${GRP_NM}-fsRoot    /           ufs     rw      1   1
/dev/gpt/${GRP_NM}-fsVar     /var        ufs     rw      2   2
/dev/gpt/${GRP_NM}-fsHome    /usr/home   ufs     rw      2   2

procfs             /proc       procfs  rw      0   0
linprocfs          /compat/linux/proc  linprocfs   rw  0   0

#/dev/gpt/data0    /mnt/Data0   exfat   auto,failok,rw,noatime,late,gid=wheel,uid=0,mountprog=/usr/local/sbin/mount.exfat-fuse   0    0
#/dev/gpt/data0    /mnt/Data0   exfat   auto,failok,rw,noatime,late,dmask=0000,fmask=0111,mountprog=/usr/local/sbin/mount.exfat-fuse   0    0

EOF


echo "Setup EFI boot" ; sleep 3
mkdir -p /mnt/boot/efi ; mount -t msdosfs /dev/${DEVX}p2 /mnt/boot/efi
(cd /mnt/boot/efi ; mkdir -p EFI/freebsd EFI/BOOT)
cp /boot/loader.efi /boot/zfsloader /mnt/boot/efi/EFI/freebsd/
cp /boot/loader.efi /mnt/boot/efi/EFI/BOOT/BOOTX64.EFI


# ifconfig wlan create wlandev ath0
# ifconfig wlan0 up scan
# dhclient wlan0

ifdev=$(ifconfig | grep '^[a-z]' | grep -ve lo0 | cut -d: -f1 | head -n 1)
#wlan_adapter=$(ifconfig | grep -B3 -i wireless) # ath0 ?
#sysctl net.wlan.devices ; sleep 3


sysctl kern.geom.debugflags ; sysctl kern.geom.debugflags=16
sysctl kern.geom.label.disk_ident.enable=0
sysctl kern.geom.label.gptid.enable=0
sysctl kern.geom.label.gpt.enable=1


echo "Extracting freebsd-dist archives" ; sleep 3
#for file in kernel base lib32 ; do
#    (fetch -o - ftp://${MIRROR}/releases/amd64/11.0-RELEASE/${file}.txz | tar --unlink -xpJf - -C ${DESTDIR:-/mnt}) ;
#done
cd /usr/freebsd-dist
for file in kernel base lib32 ; do
    (cat ${file}.txz | tar --unlink -xpJf - -C ${DESTDIR:-/mnt}) ;
done


cat << EOFchroot | chroot /mnt /bin/sh
set -x

chmod 1777 /tmp ; chmod 1777 /var/tmp
ln -s /usr/home /home


echo "Config keymap" ; sleep 3
sysrc keymap="us"
#kbdmap


echo "Config time zone" ; sleep 3
tzsetup UTC


sh -c 'cat >> /boot/loader.conf' << EOF
#vfs.root.mountfrom="ufs:gpt/${GRP_NM}-fsRoot"
#vfs.root.mountfrom="zfs:fspool0/ROOT/default"

EOF
sysrc -f /boot/loader.conf linux_load="YES"
sysrc -f /boot/loader.conf cuse4bsd_load="YES"
sysrc -f /boot/loader.conf fuse_load="YES"
sysrc -f /boot/loader.conf fusefs_load="YES"
#sysrc -f /boot/loader.conf if_ath_load="YES"

sysrc fuse_enable="YES"
sysrc fusefs_enable="YES"
sysrc linux_enable="YES"

sh -c 'cat >> /etc/sysctl.conf' << EOF
kern.geom.label.disk_ident.enable="0"
kern.geom.label.gptid.enable="0"
kern.geom.label.gpt.enable="1"

EOF


echo "Config hostname ; network" ; sleep 3
sysrc hostname="${INIT_HOSTNAME}"
#sysrc wlans_ath0="${ifdev}"
#sysrc create_args_wlan0="country US regdomain FCC"
#sysrc ifconfig_${ifdev}="WPA SYNCDHCP"
sysrc ifconfig_${ifdev}="SYNCDHCP"
sysrc ifconfig_${ifdev}_ipv6="inet6 accept_rtadv"
sh -c 'cat >> /etc/resolv.conf' << EOF
nameserver 8.8.8.8

EOF

#resolvconf -u
cat /etc/resolv.conf ; sleep 5
sed -i '' '/127.0.1.1/d' /etc/hosts
echo "127.0.1.1    ${INIT_HOSTNAME}.localdomain    ${INIT_HOSTNAME}" >> /etc/hosts


echo "Update services" ; sleep 3
sysrc ntpd_enable="YES"
sysrc ntpd_sync_on_start="YES"
sysrc sshd_enable="YES"


ASSUME_ALWAYS_YES=yes pkg -o OSVERSION=9999999 update -f
ABI=\$(pkg config abi)
#pkg install -y nano sudo xfce
pkg install -y nano sudo


echo "Set root passwd ; add user" ; sleep 3
#echo -n "${PLAIN_PASSWD}" | pw usermod root -h 0
echo -n '${CRYPTED_PASSWD}' | pw usermod root -H 0
pw groupadd usb ; pw groupmod usb -m root

mkdir -p /home/packer
#echo -n "${PLAIN_PASSWD}" | pw useradd packer -h 0 -m -G wheel,operator -s /bin/tcsh -d /home/packer -c "Packer User"
echo -n '${CRYPTED_PASSWD}' | pw useradd packer -H 0 -m -G wheel,operator -s /bin/tcsh -d /home/packer -c "Packer User"
chown -R packer:\$(id -gn packer) /home/packer

#sh -c 'cat >> /usr/local/etc/sudoers.d/99_packer' << EOF
#Defaults:packer !requiretty
#\$(id -un packer) ALL=(ALL) NOPASSWD: ALL
#EOF
#chmod 0440 /usr/local/etc/sudoers.d/99_packer


cd /etc/mail ; make aliases


echo "Temporarily permit root login via ssh password" ; sleep 3
sed -i '' "/PermitRootLogin/ s|^\(.*\)$|PermitRootLogin yes|" /etc/ssh/sshd_config

sed -i '' "/^%wheel.*(ALL)\s*ALL/ s|%wheel|# %wheel|" /usr/local/etc/sudoers
sed -i '' "/^#.*%wheel.*NOPASSWD.*/ s|^#.*%wheel|%wheel|" /usr/local/etc/sudoers
sed -i '' "s|^[^#].*requiretty|# Defaults requiretty|" /usr/local/etc/sudoers


echo "Config pkg repo nearby mirror(s)" ; sleep 3
mkdir -p /usr/local/etc/pkg/repos
sh -c 'cat >> /usr/local/etc/pkg/repos/FreeBSD.conf' << EOF
FreeBSD: { enabled: false }

FreeBSD-nearby: {
	#url: "pkg+http://${MIRRORPKG:-pkg0.nyi.freebsd.org}/\$\{ABI}/quarterly",
	url: "pkg+http://${MIRRORPKG:-pkg0.nyi.freebsd.org}/\${ABI:-FreeBSD:13:amd64}/quarterly",
	mirror_type: "srv",
	signature_type: "fingerprints",
	fingerprints: "/usr/share/keys/pkg",
	enabled: true
}

EOF

ASSUME_ALWAYS_YES=yes pkg -o OSVERSION=9999999 update -f
ASSUME_ALWAYS_YES=yes pkg clean -y
fsck_ffs -E -Z /dev/gpt/${GRP_NM}-fsRoot
fsck_ffs -E -Z /dev/gpt/${GRP_NM}-fsVar
sync

exit

EOFchroot
# end chroot commands

(cd /mnt/boot/efi ; efibootmgr -c -l EFI/freebsd/loader.efi -L FreeBSD)
(cd /mnt/boot/efi ; efibootmgr -c -l EFI/BOOT/BOOTX64.EFI -L Default)
efibootmgr -v ; sleep 3
#read -p "Activate EFI BootOrder XXXX (or blank line to skip): " bootorder
#if [ ! -z "$bootorder" ] ; then
#  efibootmgr -a -b $bootorder ;
#fi
for bootorder in $(efibootmgr | sed -n 's|.*Boot\([0-9][0-9]*\).*|\1|p') ; do
  efibootmgr -a -b $bootorder ;
done


tar -xf /tmp/init.tar -C /mnt/root/ ; sleep 5

read -p "Enter 'y' if ready to unmount & reboot [yN]: " response
if [ "y" = "$response" ] || [ "Y" = "$response" ] ; then
  umount /mnt/boot/efi ; rm -r /mnt/boot/efi ;
  sync ; swapoff -a ; umount -a ;
  reboot ; #poweroff ;
fi
