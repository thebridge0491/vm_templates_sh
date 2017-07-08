#!/bin/sh -x

# nc -l [-p] {port} > file ## nc -w3 {host} {port} < file  # netcat xfr
# ssh user@ipaddr "sudo sh -xs - arg1 argN" < script.sh  # w/ sudo
# ssh user@ipaddr "su -m root -c 'sh -xs - arg1 argN'" < script.sh

#sh /tmp/disk_setup.sh part_vmdisk ffs
#sh /tmp/disk_setup.sh format_partitions ffs
#sh /tmp/disk_setup.sh mount_filesystems

# passwd crypted hash: [md5|sha256|sha512] - [$1|$5|$6]$...
# python -c "import crypt,getpass ; print(crypt.crypt(getpass.getpass(), '\$6\$16CHARACTERSSALT'))"
# perl -e "print crypt('password', '\$6\$16CHARACTERSSALT') . \"\n\""

set -x
export DEVX=${DEVX:-sd0} ; export ARCH=${ARCH:-$(arch -s)}
export REL=${REL:-$(sysctl -n kern.osrelease)}
export MIRROR=${MIRROR:-mirror.math.princeton.edu/pub/OpenBSD}
ADD_VAGRANTUSER=${ADD_VAGRANTUSER:-0}

export PLAIN_PASSWD=${1:-abcd0123}
#export CRYPTED_PASSWD=${1:-\$6\$16CHARACTERSSALT\$o/XwaDmfuxBWVf1nEaH34MYX8YwFlAMo66n1.L3wvwdalv0IaV2b/ajr7xNcX/RFIPvfBNj.2Qxeh7v4JTjJ91}
export INIT_HOSTNAME=${2:-openbsd-boxv0000}

echo "Create/edit /etc/fstab" ; sleep 3
mkdir -p /mnt/etc /mnt/root
sh -c 'cat >> /mnt/etc/fstab' << EOF
/dev/${DEVX}a	/			ffs		rw					1	1
/dev/${DEVX}d	/var		ffs		rw,nodev,nosuid		1	2
/dev/${DEVX}e	/usr/local	ffs		rw,wxallowed,nodev	1	2
/dev/${DEVX}f	/home		ffs		rw,nodev,nosuid		1	2

/dev/${DEVX}b	none		swap	sw		0	0

swap			/tmp		mfs		rw,nodev,nosuid,-s=512m		0	0

#procfs             /proc       procfs  rw      0   0
#linprocfs          /compat/linux/proc  linprocfs   rw  0   0

EOF

sed -i 's|rw|rw,noatime|' /mnt/etc/fstab


# ifconfig wlan create wlandev ath0
# ifconfig wlan0 up scan
# dhclient wlan0

#ifdev=$(ifconfig | grep '^[a-z]' | grep -ve lo0 | cut -d: -f1 | head -n 1)
#wlan_adapter=$(ifconfig | grep -B3 -i wireless) # ath0 ?
#sysctl net.wlan.devices ; sleep 3


echo "Extracting openbsd dist archives" ; sleep 3
DESTDIR=/mnt ; SUF=$(echo ${REL} | sed 's|\.||g')
#cd /mnt2/cdrom/${REL}/${ARCH}
for file in man${SUF} comp${SUF} base${SUF} ; do
    #(cat ${file}.tgz | tar -xpzf - -C ${DESTDIR:-/}) ;
    (ftp -o - http://${MIRROR}/${REL}/${ARCH}/${file}.tgz | tar -xpzf - -C ${DESTDIR:-/}) ;
done
#cp /mnt2/cdrom/${REL}/${ARCH}/bsd* ${DESTDIR}
ftp -o ${DESTDIR}/bsd http://${MIRROR}/${REL}/${ARCH}/bsd
ftp -o ${DESTDIR}/bsd.rd http://${MIRROR}/${REL}/${ARCH}/bsd.rd
ftp -o ${DESTDIR}/bsd.mp http://${MIRROR}/${REL}/${ARCH}/bsd.mp


echo "Setup EFI boot" ; sleep 3
mkdir -p /mnt/efi ; mount -t msdos /dev/${DEVX}i /mnt/efi
(cd /mnt/efi ; mkdir -p EFI/openbsd EFI/BOOT)
#ftp -o /mnt/efi/EFI/BOOT/BOOTX64.EFI http://${MIRROR}/${REL}/${ARCH}/BOOTX64.EFI
cp /mnt/usr/mdec/{BOOTX64.EFI,bootx64.efi} /mnt/efi/EFI/openbsd/
cp /mnt/usr/mdec/{BOOTX64.EFI,bootx64.efi} /mnt/efi/EFI/BOOT/


cp /mnt/usr/mdec/boot /mnt/boot
installboot -v ${DEVX}a /mnt/usr/mdec/biosboot /mnt/usr/mdec/boot
installboot -v /dev/r${DEVX}a /mnt/usr/mdec/biosboot /mnt/usr/mdec/boot
sync ; sleep 5


(cd /mnt/dev ; sh MAKEDEV all)


# ?? missing from new install
cp /etc/group /etc/passwd /etc/master.passwd /mnt/etc/

encrypted_passwd=$(echo -n ${PLAIN_PASSWD} | encrypt)
encrypted_passwd_vagrant=$(echo -n vagrant | encrypt)

cat << EOFchroot | chroot /mnt /bin/sh
set -x

mkdir -p /tmp /var/tmp
chmod 1777 /tmp ; chmod 1777 /var/tmp
#ln -s /usr/home /home


ldconfig /usr/local/lib
sysmerge


#echo "Config keymap" ; sleep 3
##kbdmap

echo "Config time zone" ; sleep 3
ln -s /usr/share/zoneinfo/Etc/UTC /etc/localtime

ifdev=\$(ifconfig | grep '^[a-z]' | grep -ve lo0 | cut -d: -f1 | head -n 1)
echo "Config hostname ; network" ; sleep 3
echo "${INIT_HOSTNAME}.localdomain" > /etc/myname

sh -c "cat > /etc/hostname.${ifdev}" << EOF
dhcp
inet6 autoconf

EOF

sh -c 'cat > /etc/hosts' << EOF
127.0.0.1	localhost
::1			localhost

EOF
sed -i '/127.0.1.1/d' /etc/hosts
echo -e "127.0.1.1    ${INIT_HOSTNAME}.localdomain    ${INIT_HOSTNAME}" >> /etc/hosts

sh -c 'cat >> /etc/resolv.conf' << EOF
#nameserver 8.8.8.8
nameserver
lookup file bind

EOF
#resolvconf -u
cat /etc/resolv.conf ; sleep 5
ifconfig ; dhclient ${ifdev} ; sleep 5


echo "Update services" ; sleep 3
#rcctl enable ntpd
rcctl enable sshd


#echo "http://${MIRROR}" > /etc/installurl
echo "https://cdn.openbsd.org/pub/OpenBSD" > /etc/installurl
pkg_add -u
pkg_add sudo-- gtar-- gmake--
#vim-- nano-- bzip2-- findutils-- ggrep-- zip-- unzip--
#xfce4


echo 'root::0:0:daemon:0:0:Charlie &:/root:/bin/ksh' >> /etc/master.passwd
chown 0:0 /etc/master.passwd ; chmod 0600 /etc/master.passwd
pwd_mkdb -p /etc/master.passwd

echo "Set root passwd ; add user" ; sleep 3
usermod -p '${encrypted_passwd}' root

#mkdir -p /home/packer
#DIR_MODE=0750 
useradd -m -G wheel,operator -s /bin/ksh -c 'Packer User' packer
usermod -p '${encrypted_passwd}' packer

chown -R packer:\$(id -gn packer) /home/packer

#sh -c 'cat >> /etc/sudoers.d/99_packer' << EOF
#Defaults:packer !requiretty
#\$(id -un packer) ALL=(ALL) NOPASSWD: ALL
#EOF
#chmod 0440 /etc/sudoers.d/99_packer


if [ ! "0" = "${ADD_VAGRANTUSER}" ] ; then
mkdir -p /home/vagrant ;
#DIR_MODE=0750 
useradd -m -G wheel,operator -s /bin/ksh -c 'Vagrant User' vagrant ;
usermod -p '${encrypted_passwd_vagrant}' vagrant ;
#echo 'set prompt = "%N@%m:%~ %# "' >> /home/vagrant/.cshrc ;
chown -R vagrant:\$(id -gn vagrant) /home/vagrant ;

#sh -c 'cat >> /etc/sudoers.d/99_vagrant' << EOF ;
#Defaults:vagrant !requiretty
#\$(id -un vagrant) ALL=(ALL) NOPASSWD: ALL
#EOF
#chmod 0440 /etc/sudoers.d/99_vagrant ;
fi


cd /etc/mail ; make aliases



echo "Temporarily permit root login via ssh password" ; sleep 3
echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config
sed -i "/PermitRootLogin/ s|^\(.*\)$|PermitRootLogin yes|" /etc/ssh/sshd_config

sh -c 'cat >> /etc/ssh/sshd_config' << EOF
TrustedUserCAKeys /etc/ssh/sshca-id_ed25519.pub
RevokedKeys /etc/ssh/krl.krl
#HostCertificate /etc/ssh/ssh_host_ed25519_key-cert.pub
#HostCertificate /etc/ssh/ssh_host_ecdsa_key-cert.pub
#HostCertificate /etc/ssh/ssh_host_rsa_key-cert.pub

EOF

sed -i "/^%wheel.*(ALL)\s*ALL/ s|%wheel|# %wheel|" /etc/sudoers
sed -i "/^#.*%wheel.*NOPASSWD.*/ s|^#.*%wheel|%wheel|" /etc/sudoers
sed -i "s|^[^#].*requiretty|# Defaults requiretty|" /etc/sudoers


pkg_add -u


echo "Update system patches" ; sleep 3
#syspatch -c ; sleep 5
sysmerge #; syspatch ; sleep 5
echo '/usr/sbin/sysmerge' >> /etc/rc.sysmerge
cat >> /etc/rc.firsttime << EOF
/usr/sbin/fw_update -v
/usr/sbin/syspatch -c
/usr/sbin/syspatch

EOF

exit

EOFchroot
# end chroot commands


for fileX in /tmp/*.disklabel /tmp/disk_setup.sh /tmp/install.sh ; do
  cp $fileX /mnt/root/ ;
done
sync

umount -a ; umount /mnt ; rm -r /mnt/efi ; sync ; sleep 3

#sync ; swapoff -a ; reboot #shutdown -p +3
sync ; reboot #shutdown -p +3
