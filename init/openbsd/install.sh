#!/bin/sh -x

# nc -l [-p] {port} > file ## nc -w3 {host} {port} < file  # netcat xfr
# ssh user@ipaddr "sudo sh -xs - arg1 argN" < script.sh  # w/ sudo
# ssh user@ipaddr "su -m root -c 'sh -xs - arg1 argN'" < script.sh

#sh /tmp/disk_setup.sh part_format
#sh /tmp/disk_setup.sh mount_filesystems

# passwd crypted hash: [md5|sha256|sha512|yescrypt] - [$1|$5|$6|$y$j9T]$...
# stty -echo ; openssl passwd -6 -salt 16CHARACTERSSALT -stdin ; stty echo
# stty -echo ; perl -le 'print STDERR "Password:\n" ; $_=<STDIN> ; chomp $_ ; print crypt($_, "\$6\$16CHARACTERSSALT")' ; stty echo
# ruby -e '["io/console","digest/sha2"].each {|i| require i} ; STDERR.puts "Password:" ; puts STDIN.noecho(&:gets).chomp.crypt("$6$16CHARACTERSSALT")'
# python -c 'import crypt,getpass ; print(crypt.crypt(getpass.getpass(), "$6$16CHARACTERSSALT"))'

set -x
if [ -n "`fdisk sd0`" ] ; then
  export DEVX=sd0 ;
elif [ -n "`fdisk wd0`" ] ; then
  export DEVX=wd0 ;
fi

export VOL_MGR=${VOL_MGR:-std}
export GRP_NM=${GRP_NM:-obsd0}
# ftp.openbsd.org/pub/OpenBSD | mirror.math.princeton.edu/pub/OpenBSD
export MIRROR=${MIRROR:-ftp.openbsd.org/pub/OpenBSD}
export ARCH_S=${ARCH_S:-$(arch -s)}
export REL=${REL:-$(sysctl -n kern.osrelease)}
export DISTARCHIVE_FETCH=${DISTARCHIVE_FETCH:-0}


# ifconfig [; ifconfig wlan create wlandev ath0 ; ifconfig wlan0 up scan]
# dhclient [-L /tmp/dhclient.leases.{ifdev}] {ifdev}
# ifconfig {ifdev} inet autoconf

# Set the time correctly
#ntpctl -s peers ; sleep 3
rdate -v -a time.nist.gov

#ifdev=$(ifconfig | grep '^[a-z]' | grep -ve lo0 | cut -d: -f1 | head -n 1)
#wlan_adapter=$(ifconfig | grep -B3 -i wireless) # ath0 ?
#sysctl net.wlan.devices ; sleep 3


export CHROOT_CMD=chroot

bootstrap() {
  echo "Extracting openbsd dist archives" ; sleep 3
  SETVER=$(echo ${REL} | sed 's|\.||g')
  if [ "0" = "${DISTARCHIVE_FETCH}" ] || [ -z "${DISTARCHIVE_FETCH}" ] ; then
    mkdir -p /mnt2 ;
    mount_cd9660 /dev/cd0a /mnt2 ; sync ; cd /mnt2/${REL}/${ARCH_S} ;
    for setX in base${SETVER} comp${SETVER} man${SETVER} xbase${SETVER} ; do
      (cat ${setX}.tgz | tar -xpzf - -C ${DESTDIR:-/mnt}) ;
    done ;
    cp -a /mnt2/${REL}/${ARCH_S}/bsd* ${DESTDIR:-/mnt} ;
  else
    for setX in base${SETVER} comp${SETVER} man${SETVER} xbase${SETVER} ; do
      (ftp -vo - http://${MIRROR}/${REL}/${ARCH_S}/${setX}.tgz | tar -xpzf - -C ${DESTDIR:-/mnt}) ;
    done ;
    ftp -vo ${DESTDIR:-/mnt}/bsd http://${MIRROR}/${REL}/${ARCH_S}/bsd ;
    ftp -vo ${DESTDIR:-/mnt}/bsd.rd http://${MIRROR}/${REL}/${ARCH_S}/bsd.rd ;
    ftp -vo ${DESTDIR:-/mnt}/bsd.mp http://${MIRROR}/${REL}/${ARCH_S}/bsd.mp ;
  fi
}


system_config() {
  export INIT_HOSTNAME=${1:-openbsd-boxv0000}
  export PASSWD_PLAIN=${2:-packer}
  #export PASSWD_CRYPTED=${2:-\$6\$16CHARACTERSSALT\$A4i3yeafzCxgDj5imBx2ZdMWnr9LGzn3KihP9Dz0zTHbxw31jJGEuuJ6OB6Blkkw0VSUkQzSjE9n4iAAnl0RQ1}

  (cd /mnt/dev ; sh MAKEDEV all)

  # ?? missing from new install
  cp -a /etc/group /etc/passwd /etc/master.passwd /mnt/etc/

  #encrypted_passwd=$(echo -n ${PASSWD_PLAIN} | encrypt)
  encrypted_passwd=$(printf '%s' ${PASSWD_PLAIN} | encrypt)

  cat << EOFchroot | ${CHROOT_CMD} /mnt /bin/sh
set -x

# ?? /var/tmp may be sym-link to /tmp ??
rm -r /var/tmp ; mkdir -p /var/tmp
chmod 1777 /tmp ; chmod 1777 /var/tmp
#ln -s /usr/home /home

ldconfig /usr/local/lib
sysmerge

#echo "Config keymap" ; sleep 3
##kbdmap

echo "Config time zone" ; sleep 3
ln -s /usr/share/zoneinfo/Etc/UTC /etc/localtime

echo "Config hostname ; network" ; sleep 3
echo "${INIT_HOSTNAME}" > /etc/myname

sh -c 'cat >> /etc/resolv.conf' << EOF
#nameserver 8.8.8.8
nameserver
lookup file bind

EOF
#resolvconf -u
cat /etc/resolv.conf ; sleep 5

sed -i '/^127.0.1.1/ s|127.0.1.1|#127.0.1.1|' /etc/hosts
echo "127.0.1.1   ${INIT_HOSTNAME}.localdomain  ${INIT_HOSTNAME}" >> /etc/hosts
hostname \$(cat /etc/myname)

ifdev=\$(ifconfig | grep '^[a-z]' | grep -ve lo0 | cut -d: -f1 | head -n 1)

sh -c "cat > /etc/hostname.\${ifdev}" << EOF
dhcp
#inet autoconf
inet6 autoconf

EOF
ifconfig ; dhclient \${ifdev} ; ifconfig \${ifdev} inet autoconf ; sleep 5


services_enabled="sshd"
pkg_list="sudo-- nano-- pciutils-- python--%3 py3-urllib3-- gtar--"
# vim-- bzip2-- findutils-- ggrep-- zip-- unzip-- xfce4--

#echo "http://${MIRROR}" > /etc/installurl
echo "https://cdn.openbsd.org/pub/OpenBSD" > /etc/installurl
pkg_add -u
for pkgX in \${pkg_list} ; do
  pkg_add \${pkgX} ;
done

echo "Config services" ; sleep 3

echo "Enable|disable services" ; sleep 3
for svc in \${services_enabled} ; do
  rcctl enable \${svc} ;
done


echo 'root::0:0:daemon:0:0:Charlie &:/root:/bin/ksh' >> /etc/master.passwd
chown 0:0 /etc/master.passwd ; chmod 0600 /etc/master.passwd
pwd_mkdb -p /etc/master.passwd

echo "Set root passwd ; add user" ; sleep 3
usermod -p '${encrypted_passwd}' root

#mkdir -p /home/packer
#DIR_MODE=0750
useradd -m -G wheel,operator -s /bin/ksh -c 'Packer User' packer
usermod -p '${encrypted_passwd}' packer

mkdir -m 0700 -p /home/packer/.ssh ; chown -R packer /home/packer

echo "@includedir /etc/sudoers.d" >> /etc/sudoers
mkdir -p /etc/sudoers.d
#sh -c 'cat | EDITOR="tee -a" visudo -f /etc/sudoers.d/99_packernopasswd' << EOF
##Defaults:packer !requiretty
#packer ALL=(ALL:ALL) NOPASSWD: ALL
#
#EOF
##chmod 0440 /etc/sudoers.d/99_packernopasswd

cd /etc/mail ; make aliases

#sed -i "/^[^#].*requiretty/ s|^|#|" /etc/sudoers
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
#sed -i "/PermitRootLogin/ s|^\(.*\)$|PermitRootLogin yes|" /etc/ssh/sshd_config
sed -i "s|.*PermitRootLogin|#PermitRootLogin|" /etc/ssh/sshd_config
echo "PermitRootLogin yes" > /etc/ssh/sshd_config.d/99-rootlogin.conf

mv /root/.forward /root/.forward.orig

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
}

bootloader() {
  mkdir -p /mnt/efi ; mount -t msdos /dev/${DEVX}i /mnt/efi
  (cd /mnt/efi ; mkdir -p EFI/openbsd EFI/BOOT)
  if [ "arm64" = "${ARCH_S}" ] || [ "aarch64" = "${ARCH_S}" ] ; then
    ftp -vo /mnt/usr/mdec/BOOTAA64.EFI http://${MIRROR}/${REL}/${ARCH_S}/BOOTAA64.EFI ;
    cp -a /mnt/usr/mdec/*64.efi /mnt/efi/EFI/openbsd/ ;
    cp -a /mnt/usr/mdec/*64.efi /mnt/efi/EFI/BOOT/ ;
  else
    ftp -vo /mnt/usr/mdec/BOOTX64.EFI http://${MIRROR}/${REL}/${ARCH_S}/BOOTX64.EFI ;
    cp -a /mnt/usr/mdec/*64.efi /mnt/efi/EFI/openbsd/ ;
    cp -a /mnt/usr/mdec/*64.efi /mnt/efi/EFI/BOOT/ ;
  fi

  cp -a /mnt/usr/mdec/boot /mnt/boot
  installboot -v ${DEVX}a ; installboot -v /dev/r${DEVX}a
  installboot -v ${DEVX}a /mnt/usr/mdec/biosboot /mnt/usr/mdec/boot
  installboot -v /dev/r${DEVX}a /mnt/usr/mdec/biosboot /mnt/usr/mdec/boot
  sync ; sleep 5

  #fsck_ffs /dev/${DEVX}a
  #fsck_ffs /dev/${DEVX}d
  sync
}

unmount_reboot() {
  read -p "Enter 'y' if ready to unmount & reboot [yN]: " response
  if [ "y" = "${response}" ] || [ "Y" = "${response}" ] ; then
    umount /mnt/efi ; rm -r /mnt/efi ;
    sync ; swapctl -d /dev/${DEVX}b ; umount -a ;
    reboot ; #shutdown -p +3 ;
  fi
}

run_install() {
  INIT_HOSTNAME=${1:-}
  PASSWD_PLAIN=${2:-}
  #PASSWD_CRYPTED=${2:-}

  bootstrap
  system_config ${INIT_HOSTNAME} ${PASSWD_PLAIN}
  bootloader
  unmount_reboot
}

#----------------------------------------
${@}
