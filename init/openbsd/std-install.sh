#!/bin/sh -x

# nc -l [-p] {port} > file ## nc -w3 {host} {port} < file  # netcat xfr
# ssh user@ipaddr "sudo sh -xs - arg1 argN" < script.sh  # w/ sudo
# ssh user@ipaddr "su -m root -c 'sh -xs - arg1 argN'" < script.sh

#sh /tmp/disk_setup.sh disklabel_vmdisk std
#sh /tmp/disk_setup.sh format_partitions std
#sh /tmp/disk_setup.sh mount_filesystems

# passwd crypted hash: [md5|sha256|sha512] - [$1|$5|$6]$...
# perl -e 'use Term::ReadKey ; print "Password:\n" ; ReadMode "noecho" ; $_=<STDIN> ; ReadMode "normal" ; chomp $_ ; print crypt($_, "\$6\$16CHARACTERSSALT") . "\n"'
# ruby -e "['io/console','digest/sha2'].each {|i| require i} ; puts 'Password:' ; puts STDIN.noecho(&:gets).chomp.crypt(\"\$6\$16CHARACTERSSALT\")"
# python -c "import crypt,getpass ; print(crypt.crypt(getpass.getpass(), \"\$6\$16CHARACTERSSALT\"))"

set -x
if [ -n "`fdisk sd0`" ] ; then
  export DEVX=sd0 ;
elif [ -n "`fdisk wd0`" ] ; then
  export DEVX=wd0 ;
fi

#export MACHINE=${MACHINE:-$(arch -s)}
export REL=${REL:-$(sysctl -n kern.osrelease)}
export MIRROR=${MIRROR:-mirror.math.princeton.edu/pub/OpenBSD} ; MACHINE=$(uname -m)

export INIT_HOSTNAME=${1:-openbsd-boxv0000}
export PLAIN_PASSWD=${2:-abcd0123}
#export CRYPTED_PASSWD=${2:-\$6\$16CHARACTERSSALT\$o/XwaDmfuxBWVf1nEaH34MYX8YwFlAMo66n1.L3wvwdalv0IaV2b/ajr7xNcX/RFIPvfBNj.2Qxeh7v4JTjJ91}

echo "Create /etc/fstab" ; sleep 3
mkdir -p /mnt/etc /mnt/root
sh -c 'cat > /mnt/etc/fstab' << EOF
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
SUF=$(echo ${REL} | sed 's|\.||g')
#for file in man${SUF} comp${SUF} base${SUF} ; do
#    (ftp -o - http://${MIRROR}/${REL}/${MACHINE}/${file}.tgz | tar -xpzf - -C ${DESTDIR:-/mnt}) ;
#done
#ftp -o ${DESTDIR:-/mnt}/bsd http://${MIRROR}/${REL}/${MACHINE}/bsd
#ftp -o ${DESTDIR:-/mnt}/bsd.rd http://${MIRROR}/${REL}/${MACHINE}/bsd.rd
#ftp -o ${DESTDIR:-/mnt}/bsd.mp http://${MIRROR}/${REL}/${MACHINE}/bsd.mp
mount_cd9660 /dev/cd0a /mnt2 ; sync ; cd /mnt2/${REL}/${MACHINE}
for file in man${SUF} comp${SUF} base${SUF} ; do
    (cat ${file}.tgz | tar -xpzf - -C ${DESTDIR:-/mnt}) ;
done
cp /mnt2/${REL}/${MACHINE}/bsd* ${DESTDIR:-/mnt}


(cd /mnt/dev ; sh MAKEDEV all)

# ?? missing from new install
cp /etc/group /etc/passwd /etc/master.passwd /mnt/etc/

encrypted_passwd=$(echo -n ${PLAIN_PASSWD} | encrypt)


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

echo "Config hostname ; network" ; sleep 3
echo "${INIT_HOSTNAME}.localdomain" > /etc/myname

sh -c 'cat >> /etc/resolv.conf' << EOF
#nameserver 8.8.8.8
nameserver
lookup file bind

EOF
#resolvconf -u
cat /etc/resolv.conf ; sleep 5

sh -c 'cat > /etc/hosts' << EOF
127.0.0.1	localhost
::1			localhost

EOF
sed -i '/127.0.1.1/d' /etc/hosts
echo "127.0.1.1    ${INIT_HOSTNAME}.localdomain    ${INIT_HOSTNAME}" >> /etc/hosts

ifdev=\$(ifconfig | grep '^[a-z]' | grep -ve lo0 | cut -d: -f1 | head -n 1)

sh -c "cat > /etc/hostname.\${ifdev}" << EOF
dhcp
inet6 autoconf

EOF
ifconfig ; dhclient \${ifdev} ; sleep 5


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


cd /etc/mail ; make aliases



echo "Temporarily permit root login via ssh password" ; sleep 3
echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config
sed -i "/PermitRootLogin/ s|^\(.*\)$|PermitRootLogin yes|" /etc/ssh/sshd_config

sed -i "/^%wheel.*(ALL)\s*ALL/ s|%wheel|# %wheel|" /etc/sudoers
sed -i "/^#.*%wheel.*NOPASSWD.*/ s|^#.*%wheel|%wheel|" /etc/sudoers
sed -i "s|^[^#].*requiretty|# Defaults requiretty|" /etc/sudoers


pkg_add -u

#fsck_ffs /dev/${DEVX}a
#fsck_ffs /dev/${DEVX}d
sync


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

tar -xf /tmp/init.tar -C /mnt/root/ ; sleep 5


mkdir -p /mnt/efi ; mount -t msdos /dev/${DEVX}i /mnt/efi
(cd /mnt/efi ; mkdir -p EFI/openbsd EFI/BOOT)
if [ "arm64" = "${MACHINE}" ] || [ "aarch64" = "${MACHINE}" ] ; then
  #ftp -o /mnt/efi/EFI/BOOT/BOOTAA64.EFI http://${MIRROR}/${REL}/${MACHINE}/BOOTAA64.EFI ;
  cp /mnt/usr/mdec/*64.efi /mnt/efi/EFI/openbsd/ ;
  cp /mnt/usr/mdec/*64.efi /mnt/efi/EFI/BOOT/ ;
else
  #ftp -o /mnt/efi/EFI/BOOT/BOOTX64.EFI http://${MIRROR}/${REL}/${MACHINE}/BOOTX64.EFI ;
  cp /mnt/usr/mdec/*64.efi /mnt/efi/EFI/openbsd/ ;
  cp /mnt/usr/mdec/*64.efi /mnt/efi/EFI/BOOT/ ;
fi

cp /mnt/usr/mdec/boot /mnt/boot
installboot -v ${DEVX}a ; installboot -v /dev/r${DEVX}a
installboot -v ${DEVX}a /mnt/usr/mdec/biosboot /mnt/usr/mdec/boot
installboot -v /dev/r${DEVX}a /mnt/usr/mdec/biosboot /mnt/usr/mdec/boot
sync ; sleep 5

read -p "Enter 'y' if ready to unmount & reboot [yN]: " response
if [ "y" = "$response" ] || [ "Y" = "$response" ] ; then
  umount /mnt/efi ; rm -r /mnt/efi ;
  sync ; swapctl -d /dev/${DEVX}b ; umount -a ;
  reboot ; #shutdown -p +3 ;
fi
