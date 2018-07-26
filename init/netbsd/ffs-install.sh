#!/bin/sh -x

# nc -l [-p] {port} > file ## nc -w3 {host} {port} < file  # netcat xfr
# ssh user@ipaddr "sudo sh -xs - arg1 argN" < script.sh  # w/ sudo
# ssh user@ipaddr "su -m root -c 'sh -xs - arg1 argN'" < script.sh

#sh /tmp/disk_setup.sh gpt_vmdisk ffs
#sh /tmp/disk_setup.sh format_partitions ffs
#sh /tmp/disk_setup.sh mount_filesystems

# passwd crypted hash: [md5|sha256|sha512] - [$1|$5|$6]$...
# python -c "import crypt,getpass ; print(crypt.crypt(getpass.getpass(), '\$6\$16CHARACTERSSALT'))"
# perl -e "print crypt('password', '\$6\$16CHARACTERSSALT') . \"\n\""

set -x
export DEVX=${DEVX:-sd0} ; export ARCH=${ARCH:-$(uname -m)}
export REL=${REL:-$(sysctl -n kern.osrelease)}
export MIRROR=${MIRROR:-mirror.math.princeton.edu/pub/NetBSD}
ADD_VAGRANTUSER=${ADD_VAGRANTUSER:-0}

export PLAIN_PASSWD=${1:-abcd0123}
#export CRYPTED_PASSWD=${1:-\$6\$16CHARACTERSSALT\$o/XwaDmfuxBWVf1nEaH34MYX8YwFlAMo66n1.L3wvwdalv0IaV2b/ajr7xNcX/RFIPvfBNj.2Qxeh7v4JTjJ91}
export INIT_HOSTNAME=${2:-netbsd-boxv0000}

idxESP=$(echo $(gpt show -l $DEVX | grep -e "bsd1-efiboot") | cut -d' ' -f3)
idxRoot=$(echo $(gpt show -l $DEVX | grep -e "bsd1-fsRoot") | cut -d' ' -f3)
dkRoot=$(dkctl $DEVX listwedges | grep -e "bsd1-fsRoot" | cut -d: -f1)
dkVar=$(dkctl $DEVX listwedges | grep -e "bsd1-fsVar" | cut -d: -f1)
dkHome=$(dkctl $DEVX listwedges | grep -e "bsd1-fsHome" | cut -d: -f1)
dkSwap=$(dkctl $DEVX listwedges | grep -e "bsd1-fsSwap" | cut -d: -f1)
dkESP=$(dkctl $DEVX listwedges | grep -e "bsd1-efiboot" | cut -d: -f1)

echo "Create/edit /etc/fstab" ; sleep 3
mkdir -p /mnt/etc /mnt/kern /mnt/proc /mnt/compat/linux/proc
sh -c 'cat >> /mnt/etc/fstab' << EOF
##/dev/${DEVX}${idxRoot}    /           ffs     rw,noatime      1   1
#/dev/${dkRoot}    /           ffs     rw,noatime      1   1
#/dev/${dkVar}     /var        ffs     rw,noatime,nodev,nosuid      1   2
#/dev/${dkHome}    /home   ffs     rw,noatime,nodev,nosuid      1   2
#
#/dev/${dkSwap}    none        swap    sw,dp      0   0

NAME=bsd1-fsRoot    /           ffs     rw,noatime      1   1
NAME=bsd1-fsVar     /var        ffs     rw,noatime,nodev,nosuid      1   2
NAME=bsd1-fsHome    /home   ffs     rw,noatime,nodev,nosuid      1   2

NAME=bsd1-fsSwap    none        swap    sw,dp      0   0

swap			/tmp		mfs		rw,-s=512m		0	0
tmpfs			/var/shm	tmpfs	rw,nodev,nosuid,-m1777,-s=512m		0	0

kernfs             /kern       kernfs  rw      0   0
ptyfs              /dev/pts    ptyfs   rw      0   0
procfs             /proc       procfs  rw      0   0
fdesc              /dev        fdesc   ro,-o=union    0   0
#linprocfs          /compat/linux/proc  linprocfs   rw  0   0

EOF


# ifconfig wlan create wlandev ath0
# ifconfig wlan0 up scan
# dhclient wlan0

ifdev=$(ifconfig | grep '^[a-z]' | grep -ve lo0 | cut -d: -f1 | head -n 1)
#wlan_adapter=$(ifconfig | grep -B3 -i wireless) # ath0 ?
#sysctl net.wlan.devices ; sleep 3


echo "Extracting netbsd dist archives" ; sleep 3
DESTDIR=/mnt
#cd /${ARCH}/binary/kernel
#(cd /mnt ; gunzip -c /${ARCH}/binary/kernel/netbsd-GENERIC.gz ; mv netbsd-GENERIC netbsd)
cd /${ARCH}/binary/sets
for file in kern-GENERIC base comp etc man misc modules tests text ; do
    (cat ${file}.tgz | tar -xhepzf - -C ${DESTDIR:-/}) ;
    #(ftp -o - http://${MIRROR}/NetBSD-${REL}/${ARCH}/binary/sets/${file}.tgz | tar -xpzf - -C ${DESTDIR:-/}) ;
done
#cd /mnt ; mv netbsd netbsd.gen ; ln -fh netbsd.gen netbsd


echo "Setup EFI boot" ; sleep 3
mkdir -p /mnt/efi ; mount_msdos -l /dev/${dkESP} /mnt/efi
(cd /mnt/efi ; mkdir -p EFI/netbsd EFI/BOOT)
cp /mnt/usr/mdec/bootx64.efi /mnt/efi/EFI/netbsd/
cp /mnt/usr/mdec/bootx64.efi /mnt/efi/EFI/BOOT/


(cd /mnt/dev ; sh MAKEDEV all)
mount_kernfs kernfs /mnt/kern ; mount_procfs procfs /mnt/proc
mount_tmpfs tmpfs /mnt/var/shm ; mount_ptyfs ptyfs /mnt/dev/pts

hash_passwd=$(pwhash ${PLAIN_PASSWD})
hash_passwd_vagrant=$(pwhash vagrant)

cat << EOFchroot | chroot /mnt /bin/sh
set -x

chmod 1777 /tmp ; chmod 1777 /var/tmp
#ln -s /usr/home /home


cat >> /etc/rc.conf << EOF
#if [ -r /etc/defaults/rc.conf ] ; then
#	. /etc/defaults/rc.conf ;
#fi
rc_configured=YES
#clear_tmp=YES
#random_file=/etc/entropy-file
#random_file=/var/db/entropy-file
#random_seed=YES

EOF


echo "Config keymap" ; sleep 3
echo "encoding us" >> /etc/wscons.conf
echo 'wscons=YES' >> /etc/rc.conf
#kbdmap


echo "Config time zone" ; sleep 3
ln -sf /usr/share/zoneinfo/Etc/UTC /etc/localtime


echo "Config hostname ; network" ; sleep 3
cat >> /etc/rc.conf << EOF
hostname=${INIT_HOSTNAME}
#ifconfig_${ifdev}=dhcp
dhcpcd=YES

EOF

sh -c 'cat >> /etc/resolv.conf' << EOF
nameserver 8.8.8.8

EOF

#resolvconf -u
cat /etc/resolv.conf ; sleep 5
sed -i '/127.0.1.1/d' /etc/hosts
echo -e "127.0.1.1    ${INIT_HOSTNAME}.localdomain    ${INIT_HOSTNAME}" >> /etc/hosts

cat > /etc/ifconfig.${ifdev} << EOF
up
media autoselect
dhcp

EOF


cat >> /etc/profile << EOF
export LANG="en_US.UTF-8"
export LC_CTYPE="en_US.UTF-8"
export LC_ALL=""

EOF

echo "Update services" ; sleep 3
cat >> /etc/rc.conf << EOF
ntpd=YES
sshd=YES

EOF


echo "#PKG_PATH=http://${MIRROR}" >> /etc/pkg_install.conf
echo "PKG_PATH=ftp://ftp.netbsd.org/pub/pkgsrc/packages/NetBSD/${ARCH}/${REL}/All" >> /etc/pkg_install.conf
PKG_PATH=http://cdn.NetBSD.org/pub/pkgsrc/packages/NetBSD/${ARCH}/${REL}/All

pkg_add -u
pkg_add -v pkgin sudo gtar gmake
#vim nano bzip2 findutils ggrep zip unzip
#lxde


echo "Set root passwd ; add user" ; sleep 3
#usermod -p '${hash_passwd}' root
passwd

#mkdir -p /home/packer
#DIR_MODE=0750 
useradd -m -G wheel,operator -s /bin/ksh -c 'Packer User' packer
usermod -p '${hash_passwd}' packer

chown -R packer:\$(id -gn packer) /home/packer

#sh -c 'cat >> /usr/pkg/etc/sudoers.d/99_packer' << EOF
#Defaults:packer !requiretty
#\$(id -un packer) ALL=(ALL) NOPASSWD: ALL
#EOF
#chmod 0440 /usr/pkg/etc/sudoers.d/99_packer


if [ ! "0" = "${ADD_VAGRANTUSER}" ] ; then
mkdir -p /home/vagrant ;
#DIR_MODE=0750 
useradd -m -G wheel,operator -s /bin/ksh -c 'Vagrant User' vagrant ;
usermod -p '${hash_passwd_vagrant}' vagrant ;
#echo 'set prompt = "%N@%m:%~ %# "' >> /home/vagrant/.cshrc ;
chown -R vagrant:\$(id -gn vagrant) /home/vagrant ;

#sh -c 'cat >> /usr/pkg/etc/sudoers.d/99_vagrant' << EOF ;
#Defaults:vagrant !requiretty
#\$(id -un vagrant) ALL=(ALL) NOPASSWD: ALL
#EOF
#chmod 0440 /usr/pkg/etc/sudoers.d/99_vagrant ;
fi


cd /etc/mail ; make aliases


echo "Temporarily permit root login via ssh password" ; sleep 3
sed -i "/PermitRootLogin/ s|^\(.*\)$|PermitRootLogin yes|" /etc/ssh/sshd_config

sh -c 'cat >> /etc/ssh/sshd_config' << EOF
TrustedUserCAKeys /etc/ssh/sshca-id_ed25519.pub
RevokedKeys /etc/ssh/krl.krl
#HostCertificate /etc/ssh/ssh_host_ed25519_key-cert.pub
#HostCertificate /etc/ssh/ssh_host_ecdsa_key-cert.pub
#HostCertificate /etc/ssh/ssh_host_rsa_key-cert.pub

EOF

sed -i "/^%wheel.*(ALL)\s*ALL/ s|%wheel|# %wheel|" /usr/pkg/etc/sudoers
sed -i "/^#.*%wheel.*NOPASSWD.*/ s|^#.*%wheel|%wheel|" /usr/pkg/etc/sudoers
sed -i "s|^[^#].*requiretty|# Defaults requiretty|" /usr/pkg/etc/sudoers


#cat >> /boot.cfg << EOF
#menu=Boot normally:rndseed /etc/entropy-file;boot netbsd
#menu=Boot single user:rndseed /etc/entropy-file;boot netbsd -s
#menu=Disable ACPI:rndseed /etc/entropy-file;boot netbsd -2
#menu=Disable ACPI and SMP:rndseed /etc/entropy-file;boot netbsd -12
#menu=Drop to boot prompt:prompt
#default=1
#timeout=15
#clear=1
#
#EOF
cat /boot.cfg ; sleep 3


pkg_add -u


exit

EOFchroot
# end chroot commands

for fileX in /tmp/disk_setup.sh /tmp/install.sh ; do
  cp $fileX /mnt/root/ ;
done
sync

umount -a ; umount /mnt/efi ; rm -r /mnt/efi ; sync

swapctl -d /dev/$dkSwap ; reboot #poweroff
