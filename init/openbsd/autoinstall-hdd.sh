#!/bin/sh -x

# nc -l [-p] {port} > file ## nc -w3 {host} {port} < file  # netcat xfr
# ssh user@ipaddr "su -c 'sh -xs - arg1 argN'" < script.sh
# ssh user@ipaddr "sudo sh -xs - arg1 argN" < script.sh  # w/ sudo

set -x
DEVX=${DEVX:-sd0} ; ADD_VAGRANTUSER=${ADD_VAGRANTUSER:-0}

export PLAIN_PASSWD=${1:-abcd0123}

(cd /dev ; sh MAKEDEV $DEVX)
fdisk -iy -g -b 960 $DEVX ; fdisk $DEVX ; sleep 3

# Always use the first line of ftplist.cgi for the default answer of "HTTP Server?".
# This is a workaround for the change introduced in the following commit:
# https://github.com/openbsd/src/commit/bf983825822b119e4047eb99486f18c58351f347
sed -i 's/\[\[ -z $_l \]\] && //' /install.sub

/install -a -f /tmp/install.conf

encrypted_passwd_vagrant=$(echo -n vagrant | encrypt)

cat << EOFchroot | chroot /mnt /bin/sh
set -x

chmod 1777 /tmp

sh -c 'cat >> /etc/fstab' << EOF
swap	/tmp	mfs		rw,nodev,nosuid,-s=512m		0	0

EOF

sed -i 's|rw|rw,noatime|' /etc/fstab

pkg_add sudo-- gtar-- gmake--
#vim-- nano-- bzip2-- findutils-- ggrep-- zip-- unzip--
#xfce4


usermod -G operator packer

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


#echo "Temporarily permit root login via ssh password" ; sleep 3
#sed -i "/PermitRootLogin/ s|^\(.*\)$|PermitRootLogin yes|" /etc/ssh/sshd_config

sed -i "/^%wheel.*(ALL)\s*ALL/ s|%wheel|# %wheel|" /etc/sudoers
sed -i "/^#.*%wheel.*NOPASSWD.*/ s|^#.*%wheel|%wheel|" /etc/sudoers
sed -i "s|^[^#].*requiretty|# Defaults requiretty|" /etc/sudoers


cp /usr/mdec/boot /boot
installboot -v ${DEVX}a /usr/mdec/biosboot /usr/mdec/boot
installboot -v /dev/r${DEVX}a /usr/mdec/biosboot /usr/mdec/boot

sync ; sleep 5


echo '/usr/sbin/sysmerge' >> /etc/rc.sysmerge
cat >> /etc/rc.firsttime << EOF
/usr/sbin/fw_update -v
/usr/sbin/syspatch -c
/usr/sbin/syspatch

EOF


exit

EOFchroot
# end chroot commands

for fileX in /tmp/*.disklabel /tmp/install.conf /tmp/autoinstall.sh /tmp/i/install.resp ; do
  cp $fileX /mnt/root/ ;
done
sync

umount -a ; umount /mnt ; sleep 3

installboot -v ${DEVX}a ; installboot -v /dev/r${DEVX}a

#sync ; swapoff -a ; reboot #shutdown -p +3
sync ; reboot #shutdown -p +3
