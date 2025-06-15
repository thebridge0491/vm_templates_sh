#!/bin/sh -x

# nc -l [-p] {port} > file ## nc -w3 {host} {port} < file  # netcat xfr
# ssh user@ipaddr "sudo sh -xs - arg1 argN" < script.sh  # w/ sudo
# ssh user@ipaddr "su -m root -c 'sh -xs - arg1 argN'" < script.sh

#sh /tmp/gpart_setup.sh part_format std fbsd0
#sh /tmp/gpart_setup.sh mount_filesystems std fbsd0

# passwd crypted hash: [md5|sha256|sha512|yescrypt] - [$1|$5|$6|$y$j9T]$...
# stty -echo ; openssl passwd -6 -salt 16CHARACTERSSALT -stdin ; stty echo
# stty -echo ; perl -le 'print STDERR "Password:\n" ; $_=<STDIN> ; chomp $_ ; print crypt($_, "\$6\$16CHARACTERSSALT")' ; stty echo
# ruby -e '["io/console","digest/sha2"].each {|i| require i} ; STDERR.puts "Password:" ; puts STDIN.noecho(&:gets).chomp.crypt("$6$16CHARACTERSSALT")'
# python -c 'import crypt,getpass ; print(crypt.crypt(getpass.getpass(), "$6$16CHARACTERSSALT"))'

set -x
if [ -e /dev/vtbd0 ] ; then
  export DEVX=vtbd0 ;
elif [ -e /dev/ada0 ] ; then
  export DEVX=ada0 ;
elif [ -e /dev/da0 ] ; then
  export DEVX=da0 ;
fi

export VOL_MGR=${VOL_MGR:-std}
export GRP_NM=${GRP_NM:-fbsd0} ; export ZPOOLNM=${ZPOOLNM:-fspool0}
# ftp.freebsd.org/pub/FreeBSD | mirror.math.princeton.edu/pub/FreeBSD
export MIRROR=${MIRROR:-ftp.freebsd.org/pub/FreeBSD}
export UNAME_M=$(uname -m)
# [sysctl -n kern.osrelease | freebsd-version] | cut -d- -f1
export RELEASE=${RELEASE:-$(sysctl -n kern.osrelease | cut -d- -f1)}
export DISTARCHIVE_FETCH=${DISTARCHIVE_FETCH:-0}


# ifconfig [; ifconfig wlan create wlandev ath0 ; ifconfig wlan0 up scan]
# dhclient [-l /tmp/dhclient.leases.{ifdev} -p /tmp/dhclient{ifdev}.pid] {ifdev}

# Set the time correctly
#ntpd -u ntp:ntp ; ntpq -p ; ntpctl -s peers ; sleep 3
#rdate -v -a time.nist.gov
ntpd -q # ntpdate -v -u -b us.pool.ntp.org

ifdev=$(ifconfig | grep '^[a-z]' | grep -ve lo0 | cut -d: -f1 | head -n 1)
#wlan_adapter=$(ifconfig | grep -B3 -i wireless) # ath0 ?
#sysctl net.wlan.devices ; sleep 3


export CHROOT_CMD=chroot

sysctl kern.geom.debugflags ; sysctl kern.geom.debugflags=16
sysctl kern.geom.label.disk_ident.enable=0
sysctl kern.geom.label.gptid.enable=0
sysctl kern.geom.label.gpt.enable=1


bootstrap() {
  echo "Extracting freebsd dist archives" ; sleep 3
  cd /usr/freebsd-dist
  for setX in kernel base ; do
    if [ "0" = "${DISTARCHIVE_FETCH}" ] || [ -z "${DISTARCHIVE_FETCH}" ] ; then
      (cat ${setX}.txz | tar --unlink -xpJf - -C ${DESTDIR:-/mnt}) ;
    else
      (fetch -o - ftp://${MIRROR}/releases/${UNAME_M}/${RELEASE}-RELEASE/${setX}.txz | tar --unlink -xpJf - -C ${DESTDIR:-/mnt}) ;
    fi ;
  done
  sleep 5
}

system_config() {
  export INIT_HOSTNAME=${1:-freebsd-boxv0000}
  #export PASSWD_PLAIN=${2:-packer}
  export PASSWD_CRYPTED=${2:-\$6\$16CHARACTERSSALT\$A4i3yeafzCxgDj5imBx2ZdMWnr9LGzn3KihP9Dz0zTHbxw31jJGEuuJ6OB6Blkkw0VSUkQzSjE9n4iAAnl0RQ1}

  cat << EOFchroot | ${CHROOT_CMD} /mnt /bin/sh
set -x

ln -s /usr/home /home
chmod 1777 /tmp ; chmod 1777 /var/tmp

service cleartmp stop

if [ ! -f /boot/loader.conf ] ; then touch /boot/loader.conf ; fi
if [ ! -f /etc/rc.conf ] ; then touch /etc/rc.conf ; fi

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

sysrc -f /boot/loader.conf security.bsd.allow_destructive_dtrace="0"
sysrc -f /boot/loader.conf cryptodev_load="YES"

sysrc linux_enable="YES"

# Set dumpdev to "AUTO" to enable crash dumps, "NO" to disable
sysrc dumpdev="AUTO"

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
#sysrc kld_list+="if_ath fusefs"
sysrc kld_list+="fusefs"
sh -c 'cat >> /etc/resolv.conf' << EOF
nameserver 8.8.8.8

EOF

#resolvconf -u
cat /etc/resolv.conf ; sleep 5
sed -i '' '/^127.0.1.1/ s|127.0.1.1|#127.0.1.1|' /etc/hosts
echo "127.0.1.1   ${INIT_HOSTNAME}.localdomain  ${INIT_HOSTNAME}" >> /etc/hosts
echo "#151.101.192.70   rubygems.org api.rubygems.org" >> /etc/hosts


#service netif restart
dhclient -l /tmp/dhclient.leases.${ifdev} -p /tmp/dhclient.${ifdev}.pid ${ifdev}


services_enabled="sshd"
services_disabled="clear_tmp"
pkg_list="pciutils nano sudo whois python py311-urllib3 gtar" # xfce

ASSUME_ALWAYS_YES=yes pkg -o OSVERSION=9999999 update -f
ABI=\$(pkg config abi)
pkg install -y \${pkg_list}

echo "Config services" ; sleep 3

echo "Enable|disable services" ; sleep 3
for svc in \${services_enabled} ; do
  sysrc \${svc}_enable="YES" ;
done
for svc in \${services_disabled} ; do
  sysrc \${svc}_enable="NO" ;
done

echo "Set root passwd ; add user" ; sleep 3
#echo -n "${PASSWD_PLAIN}" | pw usermod root -h 0
echo -n '${PASSWD_CRYPTED}' | pw usermod root -H 0
pw groupadd usb ; pw groupmod usb -m root

mkdir -p /home/packer
#echo -n "${PASSWD_PLAIN}" | pw useradd packer -h 0 -m -G wheel,operator -s /bin/sh -d /home/packer -c "Packer User"
echo -n '${PASSWD_CRYPTED}' | pw useradd packer -H 0 -m -G wheel,operator -s /bin/sh -d /home/packer -c "Packer User"
mkdir -m 0700 -p /home/packer/.ssh ; chown -R packer /home/packer

#sh -c 'cat | EDITOR="tee -a" visudo -f /usr/local/etc/sudoers.d/99_packernopasswd' << EOF
##Defaults:packer !requiretty
#packer ALL=(ALL:ALL) NOPASSWD: ALL
#
#EOF
##chmod 0440 /usr/local/etc/sudoers.d/99_packernopasswd


cd /etc/mail ; make aliases


#sed -i '' "/^[^#].*requiretty/ s|^|#|" /usr/local/etc/sudoers
cat << EOF | EDITOR="tee -a" visudo -f /usr/local/etc/sudoers.d/99_wheelnopasswd
#Defaults:%wheel !requiretty
%wheel ALL=(ALL:ALL) NOPASSWD: ALL

EOF


mkdir -p /etc/ssh/sshd_config.d
if [ -z "\$(grep 'Include /etc/ssh/sshd_config.d/*.conf' /etc/ssh/sshd_config)" ] ; then
  echo "Include /etc/ssh/sshd_config.d/*.conf" >> /etc/ssh/sshd_config ;
fi
echo "Temporarily permit root login via ssh password" ; sleep 3
#sed -i '' "/PermitRootLogin/ s|^\(.*\)$|PermitRootLogin yes|" /etc/ssh/sshd_config
sed -i '' "s|.*PermitRootLogin|#PermitRootLogin|" /etc/ssh/sshd_config
echo "PermitRootLogin yes" > /etc/ssh/sshd_config.d/99-rootlogin.conf


echo "Config pkg repo nearby mirror(s)" ; sleep 3
mkdir -p /usr/local/etc/pkg/repos
sh -c 'cat >> /usr/local/etc/pkg/repos/FreeBSD.conf' << EOF
FreeBSD: {
  #url: "pkg+http://pkg.freebsd.org/\$\{ABI}/quarterly",
  url: "pkg+http://pkg.freebsd.org/\$(pkg config abi)/quarterly",
  mirror_type: "srv",
  signature_type: "fingerprints",
  fingerprints: "/usr/share/keys/pkg",
  enabled: false
}

FreeBSD-nearby: {
  #url: "http://${MIRRORPKG:-pkg0.nyi.freebsd.org}/\$\{ABI}/quarterly",
  url: "http://${MIRRORPKG:-pkg0.nyi.freebsd.org}/\$(pkg config abi)/quarterly",
  #mirror_type: "none",
  signature_type: "fingerprints",
  fingerprints: "/usr/share/keys/pkg",
  enabled: true
}

EOF

ASSUME_ALWAYS_YES=yes pkg -o OSVERSION=9999999 update -f
ASSUME_ALWAYS_YES=yes pkg clean -y

exit

EOFchroot
# end chroot commands
}

bootloader() {
  if [ "zfs" = "${VOL_MGR}" ] ; then
    mkdir -p /mnt/boot /mnt/etc ;
    #touch /mnt/boot/loader.conf /mnt/etc/sysctl.conf /mnt/etc/rc.conf ;
    touch /mnt/boot/loader.conf /mnt/etc/sysctl.conf \
      /mnt/etc/rc.conf ;
    sysrc -f /mnt/boot/loader.conf zfs_load="YES" ;
    cat << EOF >> /mnt/etc/sysctl.conf ;
vfs.zfs.min_auto_ashift=12

EOF
    sysrc -f /mnt/etc/rc.conf zfs_enable="YES" ;
    sysrc -f /mnt/etc/periodic.conf daily_status_zfs_enable="YES" ;
    gpart bootcode -b /mnt/boot/pmbr -p /mnt/boot/gptzfsboot -i 1 ${DEVX} ;
  else
    gpart bootcode -b /mnt/boot/pmbr -p /mnt/boot/gptboot -i 1 ${DEVX} ;
  fi

  echo "Setup EFI boot" ; sleep 3
  if [ "arm64" = "${UNAME_M}" ] || [ "aarch64" = "${UNAME_M}" ] ; then
    cp -a /mnt/boot/loader.efi /mnt/boot/efi/EFI/BOOT/BOOTAA64.EFI ;
    (cd /mnt/boot/efi ; efibootmgr -c -l EFI/freebsd/loader.efi -L "freebsd#${GRP_NM}") ;
    (cd /mnt/boot/efi ; efibootmgr -c -l EFI/BOOT/BOOTAA64.EFI -L Default) ;
  else
    cp -a /mnt/boot/loader.efi /mnt/boot/efi/EFI/BOOT/BOOTX64.EFI ;
    (cd /mnt/boot/efi ; efibootmgr -c -l EFI/freebsd/loader.efi -L "freebsd#${GRP_NM}") ;
    (cd /mnt/boot/efi ; efibootmgr -c -l EFI/BOOT/BOOTX64.EFI -L Default) ;
  fi
  find /mnt -ipath /boot/efi/*/*.efi ; sleep 5
  efibootmgr -v ; sleep 3
  #read -p "Activate EFI BootOrder XXXX (or blank line to skip): " bootorder
  #if [ ! -z "${bootorder}" ] ; then
  #  efibootmgr -a -b ${bootorder} ;
  #fi
  for bootorder in $(efibootmgr | sed -n 's|.*Boot\([0-9][0-9]*\).*|\1|p') ; do
    efibootmgr -a -b ${bootorder} ;
  done

  cat << EOFchroot | ${CHROOT_CMD} /mnt /bin/sh
set -x

mkpasswd -m help ; sleep 10
/etc/rc.d/os-release start   # populate /etc/os-release

ASSUME_ALWAYS_YES=yes pkg clean -y

exit

EOFchroot

  if [ "zfs" = "${VOL_MGR}" ] ; then
    zpool trim ${ZPOOLNM} ; zpool set autotrim=on ${ZPOOLNM} ;
  else
    fsck_ffs -E -Z /dev/gpt/${GRP_NM}-fsRoot ;
    fsck_ffs -E -Z /dev/gpt/${GRP_NM}-fsVar ;
  fi
  sync
}

unmount_reboot() {
  read -p "Enter 'y' if ready to unmount & reboot [yN]: " response
  if [ "y" = "${response}" ] || [ "Y" = "${response}" ] ; then
    umount /mnt/boot/efi ; rm -r /mnt/boot/efi ;
    sync ; swapoff -a ; umount -a ;
    if [ "zfs" = "${VOL_MGR}" ] ; then
      zfs umount -a ; zpool export ${ZPOOLNM} ;
    fi ;
    reboot ; #poweroff ;
  fi
}

run_install() {
  INIT_HOSTNAME=${1:-}
  #PASSWD_PLAIN=${2:-}
  PASSWD_CRYPTED=${2:-}

  bootstrap
  system_config ${INIT_HOSTNAME} ${PASSWD_CRYPTED}
  bootloader
  unmount_reboot
}

#----------------------------------------
${@}
