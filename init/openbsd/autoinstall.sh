#!/bin/sh -x

# nc -l [-p] {port} > file ## nc -w3 {host} {port} < file  # netcat xfr
# ssh user@ipaddr "su -c 'sh -xs - arg1 argN'" < script.sh
# ssh user@ipaddr "sudo sh -xs - arg1 argN" < script.sh  # w/ sudo

set -x
if [ -n "`fdisk sd0`" ] ; then
  export DEVX=sd0 ;
elif [ -n "`fdisk wd0`" ] ; then
  export DEVX=wd0 ;
fi

export PASSWD_PLAIN=${1:-packer}

# Set the time correctly
#ntpctl -s peers ; sleep 3
#rdate -v -a time.nist.gov

export CHROOT_CMD=chroot

(cd /dev ; sh MAKEDEV ${DEVX})
fdisk -iy -g -b 960 ${DEVX} ; sync ; fdisk ${DEVX} ; sleep 3

# Always use the first line of ftplist.cgi for the default answer of "HTTP Server?".
# This is a workaround for the change introduced in the following commit:
# https://github.com/openbsd/src/commit/bf983825822b119e4047eb99486f18c58351f347
#sed -i 's/\[\[ -z $_l \]\] && //' /install.sub

/install -a -f /tmp/install.resp ; sync

cat << EOFchroot | ${CHROOT_CMD} /mnt /bin/sh
set -x

# ?? /var/tmp may be sym-link to /tmp ??
rm -r /var/tmp ; mkdir -p /var/tmp
chmod 1777 /tmp ; chmod 1777 /var/tmp

sh -c 'cat >> /etc/fstab' << EOF
swap  /tmp  mfs   rw,nodev,nosuid,-s=512m   0  0

EOF

sed -i 's|rw|rw,noatime|' /etc/fstab

init_hostname=\$(hostname -s)
sed -i '/^127.0.1.1/ s|127.0.1.1|#127.0.1.1|' /etc/hosts
echo "127.0.1.1   \${init_hostname}.localdomain  \${init_hostname}" >> /etc/hosts
sed -n '/\.localdomain/ s|^.* \(.*\)\.localdomain.*$|\1|p' /etc/hosts \
  > /etc/myname
hostname \$(cat /etc/myname)


services_enabled="sshd"
pkg_list="sudo-- nano-- pciutils-- py3-pip-- py3-urllib3-- gtar--"
# vim-- bzip2-- findutils-- ggrep-- zip-- unzip-- xfce4--

pkg_add -u
pkg_add -ziU \${pkgX_list}

echo "Config services" ; sleep 3

echo "Enable|disable services" ; sleep 3
for svc in \${services_enabled} ; do
  rcctl enable \${svc} ;
done


usermod -G operator packer
mkdir -m 0700 -p /home/packer/.ssh ; chown -R packer /home/packer

echo "@includedir /etc/sudoers.d" >> /etc/sudoers
mkdir -p /etc/sudoers.d
#sh -c 'cat | EDITOR="tee -a" visudo -f /etc/sudoers.d/99_packernopasswd' << EOF
##Defaults:packer !requiretty
#packer ALL=(ALL) NOPASSWD: ALL
#
#EOF
##chmod 0440 /etc/sudoers.d/99_packernopasswd


#sed -i '/^[^#].*requiretty/ s|^|#|' /etc/sudoers
cat << EOF | EDITOR="tee -a" visudo -f /etc/sudoers.d/99_wheelnopasswd
#Defaults:%wheel !requiretty
%wheel ALL=(ALL:ALL) NOPASSWD: ALL

EOF
echo "#Defaults:%wheel !requiretty" >> /etc/sudoers.d/99_wheelnopasswd
echo "%wheel ALL=(ALL:ALL) NOPASSWD: ALL" >> /etc/sudoers.d/99_wheelnopasswd

mkdir -p /etc/ssh/sshd_config.d
if [ -z "\$(grep 'Include /etc/ssh/sshd_config.d/*.conf' /etc/ssh/sshd_config)" ] ; then
  echo "Include /etc/ssh/sshd_config.d/*.conf" >> /etc/ssh/sshd_config ;
fi
echo "Temporarily permit root login via ssh password" ; sleep 3
#sed -i '/PermitRootLogin/ s|^\(.*\)$|PermitRootLogin yes|' /etc/ssh/sshd_config
sed -i 's|.*PermitRootLogin|#PermitRootLogin|' /etc/ssh/sshd_config
echo "PermitRootLogin yes" > /etc/ssh/sshd_config.d/99-rootlogin.conf

mv /root/.forward /root/.forward.orig

cp -a /usr/mdec/boot /boot ; cp -a /usr/mdec/* /
installboot -v ${DEVX:-sd0}
installboot -v ${DEVX:-sd0}a
installboot -v ${DEVX:-sd0} /usr/mdec/biosboot /usr/mdec/boot
installboot -v ${DEVX:-sd0}a /usr/mdec/biosboot /usr/mdec/boot
installboot -v /dev/r${DEVX:-sd0}a /usr/mdec/biosboot /usr/mdec/boot

sync ; sleep 5


#fsck_ffs /dev/${DEVX:-sd0}a
#fsck_ffs /dev/${DEVX:-sd0}}d
sync


echo '/usr/sbin/sysmerge' >> /etc/rc.sysmerge
cat >> /etc/rc.firsttime << EOF
/usr/sbin/fw_update -v
/usr/sbin/syspatch -c
/usr/sbin/syspatch

EOF


exit

EOFchroot
# end chroot commands

cp /tmp/install.resp /mnt/root/install.resp.orig
for fileX in /tmp/*.disklabel /tmp/autoinstall.sh /tmp/i/install.resp ; do
  cp -a ${fileX} /mnt/root/ ;
done
sync

umount -a ; umount /mnt ; sleep 3

installboot -v ${DEVX:-sd0}a ; installboot -v /dev/r${DEVX:-sd0}a

#sync ; swapoff -a ; #reboot #shutdown -p +3
sync ; #reboot #shutdown -p +3
