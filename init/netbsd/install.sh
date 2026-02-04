#!/bin/sh -x

# nc -l [-p] {port} > file ## nc -w3 {host} {port} < file  # netcat xfr
# ssh user@ipaddr "sudo sh -xs - arg1 argN" < script.sh  # w/ sudo
# ssh user@ipaddr "su -m root -c 'sh -xs - arg1 argN'" < script.sh

#sh /tmp/disk_setup.sh part_format std nbsd0
#sh /tmp/disk_setup.sh mount_filesystems std nbsd0

# passwd crypted hash: [md5|sha256|sha512|yescrypt] - [$1|$5|$6|$y$j9T]$...
# stty -echo ; openssl passwd -6 -salt 16CHARACTERSSALT -stdin ; stty echo
# stty -echo ; perl -le 'print STDERR "Password:\n" ; $_=<STDIN> ; chomp $_ ; print crypt($_, "\$6\$16CHARACTERSSALT")' ; stty echo
# ruby -e '["io/console","digest/sha2"].each {|i| require i} ; STDERR.puts "Password:" ; puts STDIN.noecho(&:gets).chomp.crypt("$6$16CHARACTERSSALT")'
# python -c 'import crypt,getpass ; print(crypt.crypt(getpass.getpass(), "$6$16CHARACTERSSALT"))'

set -x
if [ -e /dev/sd0 ] ; then
  export DEVX=sd0 ;
elif [ -e /dev/wd0 ] ; then
  export DEVX=wd0 ;
fi

export VOL_MGR=${VOL_MGR:-std}
export GRP_NM=${GRP_NM:-nbsd0} ; export ZPOOLNM=${ZPOOLNM:-fspool0}
export UNAME_M=${UNAME_M:-$(uname -m)}
# ftp.netbsd.org/pub/NetBSD | mirror.math.princeton.edu/pub/NetBSD
export MIRROR=${MIRROR:-ftp.netbsd.org/pub/NetBSD}
export REL=${REL:-$(sysctl -n kern.osrelease)}
export DISTARCHIVE_FETCH=${DISTARCHIVE_FETCH:-0}


# ifconfig [; ifconfig wlan create wlandev ath0 ; ifconfig wlan0 up scan]
# dhcpcd {ifdev}

# Set the time correctly
#ntpd -u ntp:ntp ; ntpq -p ; ntpctl -s peers ; sleep 3
#rdate -s time.nist.gov
ntpd -q # ntpdate -v -u -b us.pool.ntp.org

ifdev=$(ifconfig | grep '^[a-z]' | grep -ve lo0 | cut -d: -f1 | head -n 1)
#wlan_adapter=$(ifconfig | grep -B3 -i wireless) # ath0 ?
#sysctl net.wlan.devices ; sleep 3


export CHROOT_CMD=chroot

idxESP=$(echo $(gpt show -l ${DEVX} | grep -e ESP) | cut -d' ' -f3)
idxRoot=$(echo $(gpt show -l ${DEVX} | grep -e "${GRP_NM}-fsRoot") | cut -d' ' -f3)
dkRoot=$(dkctl ${DEVX} listwedges | grep -e "${GRP_NM}-fsRoot" | cut -d: -f1)
dkVar=$(dkctl ${DEVX} listwedges | grep -e "${GRP_NM}-fsVar" | cut -d: -f1)
dkHome=$(dkctl ${DEVX} listwedges | grep -e "${GRP_NM}-fsHome" | cut -d: -f1)
dkSwap=$(dkctl ${DEVX} listwedges | grep -e "${GRP_NM}-fsSwap" | cut -d: -f1)
dkESP=$(dkctl ${DEVX} listwedges | grep -e ESP | cut -d: -f1)


bootstrap() {
  echo "Extracting netbsd dist archives" ; sleep 3
  if [ "0" = "${DISTARCHIVE_FETCH}" ] || [ -z "${DISTARCHIVE_FETCH}" ] ; then
    cd /${UNAME_M}/binary/kernel ;
    (cd /mnt ; gunzip -c /${UNAME_M}/binary/kernel/netbsd-GENERIC.gz > netbsd-GENERIC ; mv netbsd-GENERIC netbsd) ;
    cd /${UNAME_M}/binary/sets ;
    for setX in kern-GENERIC base comp etc man misc modules text xbase ; do
      (cat ${setX}.tar.xz | tar -xpJf - -C ${DESTDIR:-/mnt}) ;
    done ;
    #cd /mnt ; mv netbsd netbsd.gen ; ln -fh netbsd.gen netbsd
  else
    for setX in kern-GENERIC base comp etc man misc modules text xbase ; do
      (ftp -vo - http://${MIRROR}/NetBSD-${REL}/${UNAME_M}/binary/sets/${setX}.tar.xz | tar -xpJf - -C ${DESTDIR:-/mnt}) ;
    done ;
  fi

  (cd /mnt/dev ; sh MAKEDEV all)
  mount_kernfs kernfs /mnt/kern ; mount_procfs procfs /mnt/proc
  mount_tmpfs tmpfs /mnt/var/shm ; mount_ptyfs ptyfs /mnt/dev/pts
}

system_config() {
  export INIT_HOSTNAME=${1:-netbsd-boxv0000}
  export PASSWD_PLAIN=${2:-packer}
  #export PASSWD_CRYPTED=${2:-\$6\$16CHARACTERSSALT\$A4i3yeafzCxgDj5imBx2ZdMWnr9LGzn3KihP9Dz0zTHbxw31jJGEuuJ6OB6Blkkw0VSUkQzSjE9n4iAAnl0RQ1}

  hash_passwd=$(pwhash ${PASSWD_PLAIN})

  cat << EOFchroot | ${CHROOT_CMD} /mnt /bin/sh
set -x

ln -s /usr/home /home
chmod 1777 /tmp ; chmod 1777 /var/tmp

cat >> /etc/rc.conf << EOF
#if [ -r /etc/defaults/rc.conf ] ; then
# . /etc/defaults/rc.conf ;
#fi
rc_configured=YES
#random_file=/etc/entropy-file
#random_file=/var/db/entropy-file
#random_seed=YES

EOF


echo "Config keymap" ; sleep 3
echo "encoding us" >> /etc/wscons.conf
#kbdmap


echo "Config time zone" ; sleep 3
ln -sf /usr/share/zoneinfo/Etc/UTC /etc/localtime


echo "Config hostname ; network" ; sleep 3
cat >> /etc/rc.conf << EOF
hostname=${INIT_HOSTNAME}
#ifconfig_${ifdev}=dhcp

EOF

sh -c 'cat >> /etc/resolv.conf' << EOF
nameserver 8.8.8.8

EOF

#resolvconf -u
cat /etc/resolv.conf ; sleep 5
sed -i '/^127.0.1.1/ s|127.0.1.1|#127.0.1.1|' /etc/hosts
echo "127.0.1.1   ${INIT_HOSTNAME}.localdomain  ${INIT_HOSTNAME}" >> /etc/hosts

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


services_enabled="dhcpcd wscons sshd"
pkg_list="sudo nano gmake pciutils ca-certificates python312 py312-urllib3 gtar" # vim bzip2 findutils ggrep zip unzip xfce4

echo "#PKG_PATH=http://${MIRROR}" >> /etc/pkg_install.conf
echo "PKG_PATH=ftp://ftp.netbsd.org/pub/pkgsrc/packages/NetBSD/${UNAME_M}/${REL}/All" >> /etc/pkg_install.conf
PKG_PATH=http://cdn.netbsd.org/pub/pkgsrc/packages/NetBSD/${UNAME_M}/${REL}/All

pkg_add -u
for pkgX in pkgin \${pkg_list} ; do
  pkg_add -v \${pkgX} ;
done
sed -i 's|#ETCCERTSDIR|ETCCERTSDIR|' /usr/pkg/etc/ca-certificates-dir.conf
export PATH=\${PATH}:/usr/pkg/sbin:/usr/pkg/bin:/sbin:/usr/sbin
pkgin -y install \${pkg_list}
sed -i 's|#ETCCERTSDIR|ETCCERTSDIR|' /usr/pkg/etc/ca-certificates-dir.conf

update-ca-certificates

echo "Enable services" ; sleep 3
for svc in \${services_enabled} ; do
  echo \${svc}=YES >> /etc/rc.conf ;
done


echo "Set root passwd ; add user" ; sleep 3
usermod -p \$(pwhash ${PASSWD_PLAIN}) root
#passwd

#mkdir -p /home/packer
#DIR_MODE=0750
useradd -m -G wheel,operator -s /bin/ksh -c 'Packer User' packer
usermod -p \$(pwhash ${PASSWD_PLAIN}) packer

mkdir -m 0700 -p /home/packer/.ssh ; chown -R packer /home/packer

mkdir -p /usr/pkg/etc/sudoers.d
#sh -c 'cat | EDITOR="tee -a" visudo -f /usr/pkg/etc/sudoers.d/99_packernopasswd' << EOF
##Defaults:packer !requiretty
#packer ALL=(ALL:ALL) NOPASSWD: ALL
#
#EOF
##chmod 0440 /usr/pkg/etc/sudoers.d/99_packernopasswd


cd /etc/mail ; make aliases


#sed -i '/^[^#].*requiretty/ s|^|#|' /usr/pkg/etc/sudoers
cat << EOF | EDITOR="tee -a" visudo -f /usr/pkg/etc/sudoers.d/99_wheelnopasswd
#Defaults:%wheel !requiretty
%wheel ALL=(ALL:ALL) NOPASSWD: ALL

EOF

mkdir -p /etc/ssh/sshd_config.d
if [ -z "\$(grep 'Include /etc/ssh/sshd_config.d/*.conf' /etc/ssh/sshd_config)" ] ; then
  echo "Include /etc/ssh/sshd_config.d/*.conf" >> /etc/ssh/sshd_config ;
fi
echo "Temporarily permit root login via ssh password" ; sleep 3
#sed -i '/PermitRootLogin/ s|^\(.*\)$|PermitRootLogin yes|' /etc/ssh/sshd_config
sed -i 's|.*PermitRootLogin|#PermitRootLogin|' /etc/ssh/sshd_config
echo "PermitRootLogin yes" > /etc/ssh/sshd_config.d/99-rootlogin.conf


#pkg_add -u
pkgin upgrade
pkgin -y clean

exit

EOFchroot
# end chroot commands
}

bootloader() {
  if [ "zfs" = "${VOL_MGR}" ] ; then
    echo 'zfs=YES' >> /mnt/etc/rc.conf ;
  fi

  mkdir -p /mnt/efi ; mount_msdos -l /dev/${dkESP} /mnt/efi
  (cd /mnt/efi ; mkdir -p EFI/netbsd EFI/BOOT)
  if [ "arm64" = "${UNAME_M}" ] || [ "aarch64" = "${UNAME_M}" ] ; then
    cp -a /mnt/usr/mdec/*64.efi /mnt/efi/EFI/netbsd/ ;
    cp -a /mnt/usr/mdec/*64.efi /mnt/efi/EFI/BOOT/ ;
  else
    cp -a /mnt/usr/mdec/*64.efi /mnt/efi/EFI/netbsd/ ;
    cp -a /mnt/usr/mdec/*64.efi /mnt/efi/EFI/BOOT/ ;
  fi

  if [ "zfs" = "${VOL_MGR}" ] ; then
    cp /boot.cfg /boot.cfg.orig ;
    cat > /boot.cfg << EOF ;
menu=Boot normally:load solaris;load zfs;rndseed /etc/entropy-file;boot netbsd
menu=Boot single user:load solaris;load zfs;rndseed /etc/entropy-file;boot netbsd -s
menu=Disable ACPI:load solaris;load zfs;rndseed /etc/entropy-file;boot netbsd -2
menu=Disable ACPI and SMP:load solaris;load zfs;rndseed /etc/entropy-file;boot netbsd -12
menu=Drop to boot prompt:load solaris;load zfs;prompt
default=1
timeout=15
clear=1

EOF
  else
    #cat >> /mnt/boot.cfg << EOF
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
  fi
  cat /mnt/boot.cfg ; sleep 3

  #fsck_ffs /dev/${dkRoot}
  #fsck_ffs /dev/${dkVar}
  sync
}

unmount_reboot() {
  echo "NOTE: On reboot, if continually rebooting to iso, hit Esc key, .. Boot Manager, .. QEMU HardDisk" > /dev/stderr

  read -p "Enter 'y' if ready to unmount & reboot [yN]: " response
  if [ "y" = "${response}" ] || [ "Y" = "${response}" ] ; then
    umount /mnt/efi ; rm -r /mnt/efi ;
    sync ; swapctl -d /dev/${dkSwap} ; umount -a ;
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
