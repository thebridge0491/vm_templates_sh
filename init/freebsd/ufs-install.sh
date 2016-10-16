#!/bin/sh -x

# nc -l [-p] {port} > file ## nc -w3 {host} {port} < file  # netcat xfr
# ssh user@ipaddr "sudo sh -xs - arg1 argN" < script.sh  # w/ sudo
# ssh user@ipaddr "su -m root -c 'sh -xs - arg1 argN'" < script.sh

#sh /tmp/disk_setup.sh gpart_vmdisk ufs
#sh /tmp/disk_setup.sh format_partitions ufs
#sh /tmp/disk_setup.sh mount_filesystems

# passwd crypted hash: [md5|sha256|sha512] - [$1|$5|$6]$...
# python -c "import crypt,getpass ; print(crypt.crypt(getpass.getpass(), '\$6\$16CHARACTERSSALT'))"
# perl -e "print crypt('password', '\$6\$16CHARACTERSSALT') . \"\n\""

set -x
export DEVX=${DEVX:-da0}
ADD_VAGRANTUSER=${ADD_VAGRANTUSER:-0}

#export PLAIN_PASSWD=${1:-abcd0123}
export CRYPTED_PASSWD=${1:-\$6\$16CHARACTERSSALT\$o/XwaDmfuxBWVf1nEaH34MYX8YwFlAMo66n1.L3wvwdalv0IaV2b/ajr7xNcX/RFIPvfBNj.2Qxeh7v4JTjJ91}
export INIT_HOSTNAME=${2:-freebsd-boxv0000}

tunefs -n enable -t enable /dev/gpt/fsRoot
tunefs -n enable -t enable /dev/gpt/fsVar
tunefs -n enable -t enable /dev/gpt/fsHome

echo "Create/edit /etc/fstab" ; sleep 3
mkdir -p /mnt/etc /mnt/compat/linux/proc
sh -c 'cat >> /mnt/etc/fstab' << EOF
/dev/gpt/fsSwap    none        swap    sw      0   0
/dev/gpt/fsRoot    /           ufs     rw      1   1
/dev/gpt/fsVar     /var        ufs     rw      2   2
/dev/gpt/fsHome    /usr/home   ufs     rw      2   2

procfs             /proc       procfs  rw      0   0
linprocfs          /compat/linux/proc  linprocfs   rw  0   0

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
cd /usr/freebsd-dist ; export DESTDIR=/mnt
for file in kernel base lib32 ; do
    (cat ${file}.txz | tar --unlink -xpJf - -C ${DESTDIR:-/}) ;
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
#vfs.root.mountfrom="ufs:gpt/fsRoot"
#vfs.root.mountfrom="zfs:zvRoot/ROOT/default"

EOF
sysrc -f /boot/loader.conf linux_load="YES"
sysrc -f /boot/loader.conf cuse4bsd_load="YES"
sysrc -f /boot/loader.conf fuse_load="YES"
#sysrc -f /boot/loader.conf if_ath_load="YES"

sysrc linux_enable="YES"
sysrc fuse_enable="YES"

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
echo -e "127.0.1.1    ${INIT_HOSTNAME}.localdomain    ${INIT_HOSTNAME}" >> /etc/hosts


echo "Update services" ; sleep 3
sysrc ntpd_enable="YES"
sysrc ntpd_sync_on_start="YES"
sysrc sshd_enable="YES"


ASSUME_ALWAYS_YES=yes pkg -o OSVERSION=9999999 update -f
#pkg install -y sudo lxde-meta
pkg install -y sudo


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


if [ ! "0" = "${ADD_VAGRANTUSER}" ] ; then
mkdir -p /home/vagrant ;
echo -n vagrant | pw useradd vagrant -h 0 -m -G wheel,operator -s /bin/tcsh -d /home/vagrant -c "Vagrant User" ;
#echo 'set prompt = "%N@%m:%~ %# "' >> /home/vagrant/.cshrc ;
chown -R vagrant:\$(id -gn vagrant) /home/vagrant ;

#sh -c 'cat >> /usr/local/etc/sudoers.d/99_vagrant' << EOF ;
#Defaults:vagrant !requiretty
#\$(id -un vagrant) ALL=(ALL) NOPASSWD: ALL
#EOF
#chmod 0440 /usr/local/etc/sudoers.d/99_vagrant ;
fi


cd /etc/mail ; make aliases


echo "Temporarily permit root login via ssh password" ; sleep 3
sed -i '' "/PermitRootLogin/ s|^\(.*\)$|PermitRootLogin yes|" /etc/ssh/sshd_config

sh -c 'cat >> /etc/ssh/sshd_config' << EOF
TrustedUserCAKeys /etc/ssh/sshca-id_ed25519.pub
RevokedKeys /etc/ssh/krl.krl
#HostCertificate /etc/ssh/ssh_host_ed25519_key-cert.pub
#HostCertificate /etc/ssh/ssh_host_ecdsa_key-cert.pub
#HostCertificate /etc/ssh/ssh_host_rsa_key-cert.pub

EOF

sed -i '' "/^%wheel.*(ALL)\s*ALL/ s|%wheel|# %wheel|" /usr/local/etc/sudoers
sed -i '' "/^#.*%wheel.*NOPASSWD.*/ s|^#.*%wheel|%wheel|" /usr/local/etc/sudoers
sed -i '' "s|^[^#].*requiretty|# Defaults requiretty|" /usr/local/etc/sudoers


echo "Config pkg repo nearby mirror(s)" ; sleep 3
mkdir -p /usr/local/etc/pkg/repos
sh -c 'cat >> /usr/local/etc/pkg/repos/FreeBSD.conf' << EOF
FreeBSD: { enabled: false }

FreeBSD-nearby: {
	url: "pkg+http://${MIRROR:-pkg0.nyi.freebsd.org}/\${ABI}/quarterly",
	mirror_type: "srv",
	signature_type: "fingerprints",
	fingerprints: "/usr/share/keys/pkg",
	enabled: true
}

EOF

ASSUME_ALWAYS_YES=yes pkg -o OSVERSION=9999999 update -f


exit

EOFchroot
# end chroot commands

for fileX in /tmp/disk_setup.sh /tmp/install.sh ; do
  cp $fileX /mnt/root/ ;
done
sync

(cd /mnt/boot/efi ; efibootmgr -c -l EFI/BOOT/BOOTX64.EFI -L Default)
(cd /mnt/boot/efi ; efibootmgr -c -l EFI/freebsd/loader.efi -L FreeBSD)
efibootmgr -v ; sleep 3
read -p "Activate EFI BootOrder XXXX (or blank line to skip): " bootorder
if [ ! -z "$bootorder" ] ; then
  efibootmgr -a $bootorder ;
fi
umount /mnt/boot/efi ; rm -r /mnt/boot/efi ; sync

sync ; swapoff -a ; reboot #poweroff
