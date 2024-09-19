#!/bin/bash -x

# nc -l [-p] {port} > file ## nc -w3 {host} {port} < file  # netcat xfr
# ssh user@ipaddr "su -c 'sh -xs - arg1 argN'" < script.sh
# ssh user@ipaddr "sudo sh -xs - arg1 argN" < script.sh  # w/ sudo

#sh /tmp/disk_setup.sh part_format sgdisk std vg0 pvol0
#sh /tmp/disk_setup.sh mount_filesystems std vg0

# passwd crypted hash: [md5|sha256|sha512|yescrypt] - [$1|$5|$6|$y$j9T]$...
# stty -echo ; openssl passwd -6 -salt 16CHARACTERSSALT -stdin ; stty echo
# stty -echo ; perl -le 'print STDERR "Password:\n" ; $_=<STDIN> ; chomp $_ ; print crypt($_, "\$6\$16CHARACTERSSALT")' ; stty echo
# ruby -e '["io/console","digest/sha2"].each {|i| require i} ; STDERR.puts "Password:" ; puts STDIN.noecho(&:gets).chomp.crypt("$6$16CHARACTERSSALT")'
# python -c 'import crypt,getpass ; print(crypt.crypt(getpass.getpass(), "$6$16CHARACTERSSALT"))'

set -x
if [ -e /dev/vda ] ; then
  export DEVX=vda ;
elif [ -e /dev/sda ] ; then
  export DEVX=sda ;
fi

export VOL_MGR=${VOL_MGR:-std}
export GRP_NM=${GRP_NM:-vg0} ; export ZPOOLNM=${ZPOOLNM:-ospool0}
export MIRROR=${MIRROR:-download.opensuse.org}
export UNAME_M=$(uname -m)
# # RELEASE: tumbleweed | slowroll | leap/15.5 | openSUSE-current
export RELEASE=${RELEASE:-openSUSE-current}


# ifconfig [;ifconfig wlan create wlandev ath0 ; ifconfig wlan0 up scan]
# networkctl status ; networkctl up {ifdev}
# nmcli device status ; nmcli connection up {ifdev}
# wicked ifstatus all ; wicked up {ifdev}

#ifdev=$(ip -o link | grep 'link/ether' | grep 'LOWER_UP' | sed -n 's|\S*: \(\w*\):.*|\1|p')


bootstrap() {
  echo "Bootstrap base pkgs" ; sleep 3
  if [ "zfs" = "${VOL_MGR}" ] ; then
    zfs umount ${ZPOOLNM}/var/mail ; zfs destroy ${ZPOOLNM}/var/mail ;
  fi
  #rm -r /mnt/var/lib/rpm /mnt/var/cache/zypp
  #mkdir -p /mnt/var/lib/rpm /mnt/var/cache/zypp
  #rpm -v --root /mnt --initdb
  #release_ver=$(curl -Ls http://${MIRROR}/distribution/${RELEASE}/repo/oss/${UNAME_M} | sed -n 's|.*openSUSE-release-\(.*\).rpm.*|\1|p') ;
  # [wget -O file url | curl -Lo file url]
  #wget -O /tmp/release.rpm http://${MIRROR}/distribution/${RELEASE}/repo/oss/${UNAME_M}/openSUSE-release-${release_ver:-15.4-lp154.153.1.${UNAME_M}}.rpm ;
  #rpm -v -qip /tmp/release.rpm ; sleep 5
  #rpm -v --root /mnt --nodeps -i /tmp/release.rpm
  if [ "tumbleweed" = "${RELEASE}" ] ; then
    #mkdir /mnt/etc/zypp/repos.d/old ;
    #mv /mnt/etc/zypp/repos.d/*.repo /mnt/etc/zypp/repos.d/old/ ;
    zypper --non-interactive --root /mnt --gpg-auto-import-keys addrepo http://${MIRROR}/distribution/openSUSE-current/repo/oss/ repo-oss
    zypper --non-interactive --root /mnt --gpg-auto-import-keys addrepo http://${MIRROR}/tumbleweed/repo/oss/ repo-ossTumbleweed
  elif [ "slowroll" = "${RELEASE}" ] ; then
    #mkdir /mnt/etc/zypp/repos.d/old ;
    #mv /mnt/etc/zypp/repos.d/*.repo /mnt/etc/zypp/repos.d/old/ ;
    zypper --non-interactive --root /mnt --gpg-auto-import-keys addrepo http://${MIRROR}/distribution/openSUSE-current/repo/oss/ repo-oss
    zypper --non-interactive --root /mnt --gpg-auto-import-keys addrepo http://${MIRROR}/slowroll/repo/oss/ repo-ossSlowroll
  else
    zypper --non-interactive --root /mnt --gpg-auto-import-keys addrepo http://${MIRROR}/distribution/${RELEASE}/repo/oss/ repo-oss
  fi
  zypper --non-interactive --root /mnt --gpg-auto-import-keys refresh
  for pkgX in patterns-base-base system-group-wheel makedev ; do
    zypper --non-interactive --root /mnt install -y --no-recommends ${pkgX} ;
  done ;
  #zypper --non-interactive --root /mnt install -y --no-recommends patterns-base-base system-group-wheel makedev
  zypper --non-interactive --root /mnt repos ; sleep 5

  echo "Prepare chroot (mount --[r]bind devices)" ; sleep 3
  cp /etc/mtab /mnt/etc/mtab
  mkdir -p /mnt/dev /mnt/proc /mnt/sys /mnt/run
  mount --rbind /proc /mnt/proc ; mount --rbind /sys /mnt/sys
  mount --rbind /dev /mnt/dev

  mount --rbind /dev/pts /mnt/dev/pts ; mount --rbind /run /mnt/run
  modprobe efivarfs
  mount -t efivarfs efivarfs /mnt/sys/firmware/efi/efivars/

  #mkdir -p /mnt/var/empty /mnt/var/lock/subsys /mnt/etc/sysconfig/network
  #cp /etc/sysconfig/network/ifcfg-${ifdev} /mnt/etc/sysconfig/network/ifcfg-${ifdev}.bak
  mkdir -p /mnt/run/netconfig ; touch /mnt/run/netconfig/resolv.conf
  cp /etc/resolv.conf /mnt/etc/resolv.conf
  sleep 5
}

system_config() {
  export INIT_HOSTNAME=${1:-suse-boxv0000}
  #export PASSWD_PLAIN=${2:-packer}
  export PASSWD_CRYPTED=${2:-\$6\$16CHARACTERSSALT\$A4i3yeafzCxgDj5imBx2ZdMWnr9LGzn3KihP9Dz0zTHbxw31jJGEuuJ6OB6Blkkw0VSUkQzSjE9n4iAAnl0RQ1}

  # LANG=[C|en_US].UTF-8
  cat << EOFchroot | LANG=C.UTF-8 LANGUAGE=en chroot /mnt /bin/sh
set -x

chmod 1777 /tmp ; chmod 1777 /var/tmp
chown root:root / ; chmod 0755 /

unset LC_ALL
export TERM=xterm-color     # xterm | xterm-color
#hostname ${INIT_HOSTNAME}

ls /proc ; sleep 5 ; ls /dev ; sleep 5

#mount -t proc none /proc
cd /dev ; MAKEDEV generic

systemctl stop sshd ; systemctl disable sshd

echo "Config pkg repo mirror(s)" ; sleep 3
. /etc/os-release

if [ "tumbleweed" = "${RELEASE}" ] ; then
  zypper --non-interactive --gpg-auto-import-keys addrepo http://${MIRROR}/distribution/openSUSE-current/repo/oss/ repo-oss
  zypper --non-interactive --gpg-auto-import-keys addrepo http://${MIRROR}/distribution/openSUSE-current/repo/non-oss/ repo-non-oss
  zypper --non-interactive --gpg-auto-import-keys addrepo http://${MIRROR}/update/openSUSE-current/ update-oss
  zypper --non-interactive --gpg-auto-import-keys addrepo http://${MIRROR}/update/openSUSE-non-oss-current/ update-non-oss
  zypper --non-interactive --gpg-auto-import-keys addrepo http://${MIRROR}/tumbleweed/repo/oss/ repo-ossTumbleweed
  zypper --non-interactive --gpg-auto-import-keys addrepo http://${MIRROR}/tumbleweed/repo/non-oss/ repo-non-ossTumbleweed
  zypper --non-interactive --gpg-auto-import-keys addrepo http://${MIRROR}/update/tumbleweed/ update-ossTumbleweed
  zypper --non-interactive --gpg-auto-import-keys addrepo http://${MIRROR}/update/tumbleweed-non-oss/ update-non-ossTumbleweed
elif [ "slowroll" = "${RELEASE}" ] ; then
  zypper --non-interactive --gpg-auto-import-keys addrepo http://${MIRROR}/distribution/openSUSE-current/repo/oss/ repo-oss
  zypper --non-interactive --gpg-auto-import-keys addrepo http://${MIRROR}/distribution/openSUSE-current/repo/non-oss/ repo-non-oss
  zypper --non-interactive --gpg-auto-import-keys addrepo http://${MIRROR}/update/openSUSE-current/ update-oss
  zypper --non-interactive --gpg-auto-import-keys addrepo http://${MIRROR}/update/openSUSE-non-oss-current/ update-non-oss
  zypper --non-interactive --gpg-auto-import-keys addrepo http://${MIRROR}/slowroll/repo/oss/ repo-ossSlowroll
  zypper --non-interactive --gpg-auto-import-keys addrepo http://${MIRROR}/slowroll/repo/non-oss/ repo-non-ossSlowroll
  zypper --non-interactive --gpg-auto-import-keys addrepo http://${MIRROR}/update/slowroll/repo/oss/ update-ossSlowroll
  #zypper --non-interactive --gpg-auto-import-keys addrepo http://${MIRROR}/update/slowroll/repo/non-oss/ update-non-ossSlowroll # ???
else # elif [ "opensuse-leap" = "\${ID}" ] ; then
  zypper --non-interactive --gpg-auto-import-keys addrepo http://${MIRROR}/distribution/leap/\${VERSION_ID}/repo/oss/ repo-oss
  zypper --non-interactive --gpg-auto-import-keys addrepo http://${MIRROR}/distribution/leap/\${VERSION_ID}/repo/non-oss/ repo-non-oss
  zypper --non-interactive --gpg-auto-import-keys addrepo http://${MIRROR}/update/leap/\${VERSION_ID}/oss/ update-oss
  zypper --non-interactive --gpg-auto-import-keys addrepo http://${MIRROR}/update/leap/\${VERSION_ID}/non-oss/ update-non-oss
fi

zypper repos ; sleep 5


echo "Add software package selection(s)" ; sleep 3
zypper --non-interactive --gpg-auto-import-keys refresh
#zypper --non-interactive install -y --no-recommends patterns-base-base
zypper --non-interactive install -y --no-recommends --type pattern base
# xfce laptop
zypper --non-interactive install -y ca-certificates-cacert ca-certificates-mozilla
zypper --gpg-auto-import-keys refresh
update-ca-certificates
for pkgX in system-group-wheel sudo whois nano less dosfstools xfsprogs dhcp-client firewalld ntp openssl openssh makedev openssh-askpass ; do
  zypper --non-interactive install -y \${pkgX} ;
done
#zypper --non-interactive install -y system-group-wheel sudo whois nano less dosfstools xfsprogs dhcp-client firewalld ntp openssl openssh makedev openssh-askpass


echo "Config keyboard ; localization" ; sleep 3
kbd_mode -u ; loadkeys us ## ?? error
sed -i '/en_US.UTF-8 UTF-8/ s|^# ||' /etc/locale.gen
echo 'LANG=en_US.UTF-8' >> /etc/locale.conf
locale-gen # en_US en_US.UTF-8

#sh -c 'cat >> /etc/default/locale' << EOF
#LANG=en_US.UTF-8
##LC_ALL=en_US.UTF-8
#LANGUAGE="en_US:en"
#
#EOF


echo "Config time zone & clock" ; sleep 3
rm /etc/localtime
ln -sf /usr/share/zoneinfo/UTC /etc/localtime
hwclock --systohc --utc


echo "Config hostname ; network" ; sleep 3
echo "${INIT_HOSTNAME}" > /etc/hostname
#sh -c 'cat >> /etc/resolv.conf' << EOF
##search hqdom.local
#nameserver 8.8.8.8
#
#EOF
cat /etc/resolv.conf ; sleep 5
sed -i '/127.0.1.1/d' /etc/hosts
echo "127.0.1.1    ${INIT_HOSTNAME}.localdomain    ${INIT_HOSTNAME}" >> /etc/hosts

ifdev=\$(ip -o link | grep 'link/ether' | grep 'LOWER_UP' | sed -n 's|\S*: \(\w*\):.*|\1|p')

sh -c "cat >> /etc/sysconfig/network/ifcfg-\${ifdev}" << EOF
BOOTPROTO='dhcp'
STARTMODE='auto'
ONBOOT='yes'

EOF
echo "NETWORKING=yes" >> /etc/sysconfig/network


echo "Set root passwd ; add user" ; sleep 3
groupadd --system wheel
#echo -n "root:${PASSWD_PLAIN}" | chpasswd
echo -n 'root:${PASSWD_CRYPTED}' | chpasswd -e

DIR_MODE=0750 useradd -m -G wheel -s /bin/bash -c 'Packer User' packer
#echo -n "packer:${PASSWD_PLAIN}" | chpasswd
echo -n 'packer:${PASSWD_CRYPTED}' | chpasswd -e
chown -R packer:\$(id -gn packer) /home/packer

sh -c 'cat >> /etc/sudoers.d/99_packer' << EOF
Defaults:packer !requiretty
#\$(id -un packer) ALL=(ALL) NOPASSWD: ALL
packer ALL=(ALL) NOPASSWD: ALL
EOF
chmod 0440 /etc/sudoers.d/99_packer


sed -i "/^%wheel.*(ALL)\s*ALL/ s|%wheel|# %wheel|" /etc/sudoers
sed -i "/^#.*%wheel.*NOPASSWD.*/ s|^#.*%wheel|%wheel|" /etc/sudoers
echo '%wheel ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers
sed -i "s|^[^#].*requiretty|# Defaults requiretty|" /etc/sudoers


systemctl enable sshd
systemctl disable firewalld

zypper --non-interactive clean

exit

EOFchroot
# end chroot commands
}

kernel_bootloader() {
# LANG=[C|en_US].UTF-8
cat << EOFchroot | LANG=C.UTF-8 LANGUAGE=en chroot /mnt /bin/sh
set -x

. /etc/os-release

##zypper --non-interactive remove busybox-sed busybox-grep # ???
#zypper --non-interactive install -y --force-resolution --no-recommends patterns-base-bootloader patterns-yast-yast2_basis
zypper --non-interactive install -y --force-resolution --no-recommends --type pattern bootloader yast2_basis
zypper --non-interactive install -y kernel-default grub2 shim efibootmgr

echo "Config dracut ; Linux kernel"
echo 'hostonly="yes"' >> /etc/dracut.conf
mkdir -p /etc/dracut.conf.d

modprobe vfat ; lsmod | grep -e fat ; sleep 5

if [ "zfs" = "${VOL_MGR}" ] ; then
  ## temp downgrade grub2[x86_64-efi|i386-pc] due to unknown filesystem error (ZFS)
  #zypper --non-interactive install -y --from repo-oss --from repo-non-oss --oldpackage grub2-i386-pc grub2-x86_64-efi shim grub2 ;
  #zypper addlock grub2-i386-pc grub2-x86_64-efi shim grub2 ;
  zypper --non-interactive install -y kernel-default-devel dkms zfs ;

  if [ "tumbleweed" = "${RELEASE}" ] ; then
    zypper --gpg-auto-import-keys addrepo http://${MIRROR}/repositories/filesystems/openSUSE_Tumbleweed/filesystems.repo ;
  elif [ "slowroll" = "${RELEASE}" ] ; then
    zypper --gpg-auto-import-keys addrepo http://${MIRROR}/repositories/filesystems/openSUSE_Slowroll/filesystems.repo ;
  else
    zypper --gpg-auto-import-keys addrepo http://${MIRROR}/repositories/filesystems/\${VERSION_ID}/filesystems.repo ;
  fi ;
  zypper --gpg-auto-import-keys refresh ;

  #zypper --non-interactive install -y kernel-default-devel dkms zfs ;
  zypper --non-interactive install -y zfs ;
  # kernel-firmware

  # ?? Error - no zfs.ko module, just binaries zfs, zpool, etc (zfs ver 2.1.2)
  find /lib/modules -type f -name '*zfs.ko*' ;
  sleep 30 ; # ?? missing zfs.ko (zfs ver 2.1.2)

  mkdir -p /etc/dkms ; echo REMAKE_INITRD=yes > /etc/dkms/zfs.conf ;
  modprobe zfs ; zfs version ; sleep 5 ;

  zgenhostid -f -o /etc/hostid ; sleep 5 ;

  sed -i '/^\[Unit\]/,/^$/!b;/^$/i\Requires=systemd-modules-load.service\nAfter=systemd-modules-load.service' \
    /etc/systemd/system/zfs-import.target.wants/zfs-import-cache.service ;
  sed -i '/^\[Service\]/,/^$/!b;/^$/i\ExecStartPre=/usr/bin/sleep 30' \
    /etc/systemd/system/zfs-import.target.wants/zfs-import-cache.service ;

  systemctl enable zfs-import-scan ; systemctl enable zfs-import-cache ;
  systemctl enable systemd-modules-load #; systemctl enable zfs-import.target ;
  systemctl enable zfs-mount ; systemctl enable zfs.target ;
  sleep 10 ;

  echo 'nofsck="yes"' >> /etc/dracut.conf.d/zol.conf ;
  echo 'add_dracutmodules+=" zfs "' >> /etc/dracut.conf.d/zol.conf ;
  echo 'omit_dracutmodules+=" btrfs resume "' >> /etc/dracut.conf.d/zol.conf ;

  echo "zfs" >> /etc/modules-load.d/zfs.conf ;
  dracut_extra_opts='--add-drivers "zfs"' ;

  echo "Hold zfs & kernel package upgrades (require manual upgrade)" ;
  zypper addlock zfs zfs-sudo kernel-default kernel-default-devel ;
  zypper locks ; sleep 3 ;
elif [ "btrfs" = "${VOL_MGR}" ] ; then
  zypper --non-interactive install -y btrfsprogs ;
  modprobe btrfs ; sleep 5 ;
elif [ "lvm" = "${VOL_MGR}" ] ; then
  zypper --non-interactive install -y lvm2 ;
  # cryptsetup
  modprobe dm-mod ; vgscan ; vgchange -ay ; lvs ; sleep 5 ;
fi

sleep 10
kver="\$(ls -A /lib/modules/ | tail -1)" # ?? or uname -r
kernel-install add \${kver} /boot/vmlinuz-\${kver}
#mkinitrd /boot/initrd-\${kver} \${kver}
dracut --kver \${kver} --force \${dracut_extra_opts}
#zypper --non-interactive install -y -f kernel-default


grub2-probe /boot

echo "Bootloader installation & config" ; sleep 3
mkdir -p /boot/efi/EFI/\${ID} /boot/efi/EFI/BOOT
if [ "aarch64" = "${UNAME_M}" ] ; then
  grub2-install --target=arm64-efi --efi-directory=/boot/efi --bootloader-id=\${ID} --recheck --removable ;
  cp -R /boot/efi/EFI/\${ID}/* /boot/efi/EFI/BOOT/ ;
  cp /boot/efi/EFI/BOOT/BOOTAA64.EFI /boot/efi/EFI/BOOT/BOOTAA64.EFI.bak ;
  cp /boot/efi/EFI/BOOT/grubaa64.EFI /boot/efi/EFI/BOOT/BOOTAA64.EFI ;
  #cp /boot/efi/EFI/\${ID}/grubaa64.efi /boot/efi/EFI/BOOT/BOOTAA64.EFI ;
else
  grub2-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=\${ID} --recheck --removable ;
  grub2-install --target=i386-pc --recheck /dev/${DEVX} ;
  cp -R /boot/efi/EFI/\${ID}/* /boot/efi/EFI/BOOT/ ;
  cp /boot/efi/EFI/BOOT/BOOTX64.EFI /boot/efi/EFI/BOOT/BOOTX64.EFI.bak ;
  cp /boot/efi/EFI/BOOT/grubx64.EFI /boot/efi/EFI/BOOT/BOOTX64.EFI ;
  #cp /boot/efi/EFI/\${ID}/grubx64.efi /boot/efi/EFI/BOOT/BOOTX64.EFI ;
fi

#sed -i -e "s|^GRUB_TIMEOUT=.*$|GRUB_TIMEOUT=1|" /etc/default/grub
#sed -i -e "/GRUB_DEFAULT/ s|=.*$|=saved|" /etc/default/grub
#echo "GRUB_SAVEDEFAULT=true" >> /etc/default/grub
#echo "#GRUB_CMDLINE_LINUX='cryptdevice=/dev/sda2:cryptroot'" >> /etc/default/grub
sed -i '/GRUB_CMDLINE_LINUX_DEFAULT/ s|="\(.*\)"|="\1 text xdriver=vesa nomodeset rootdelay=5"|'  \
  /etc/default/grub

if [ "zfs" = "${VOL_MGR}" ] ; then
  sed -i -e '/GRUB_CMDLINE_LINUX_DEFAULT/ s|nomodeset rootdelay|nomodeset root=ZFS=${ZPOOLNM}/ROOT/default rootdelay|' /etc/default/grub ;
  echo 'GRUB_PRELOAD_MODULES="zfs"' >> /etc/default/grub ;
elif [ "btrfs" = "${VOL_MGR}" ] ; then
  echo 'GRUB_PRELOAD_MODULES="btrfs"' >> /etc/default/grub ;
elif [ "lvm" = "${VOL_MGR}" ] ; then
  echo 'GRUB_PRELOAD_MODULES="lvm"' >> /etc/default/grub ;
fi

if [ "\$(dmesg | grep -ie 'Hypervisor detected')" ] ; then
  sed -i -e '/GRUB_CMDLINE_LINUX_DEFAULT/ s|="\(.*\)"|="\1 net.ifnames=0 biosdevname=0"|' /etc/default/grub ;
fi
grub2-mkconfig -o /boot/grub2/grub.cfg
#cp -f /boot/efi/EFI/\${ID}/grub.cfg /boot/grub2/grub.cfg
#cp -f /boot/efi/EFI/\${ID}/grub.cfg /boot/efi/EFI/BOOT/grub.cfg

if [ "aarch64" = "${UNAME_M}" ] ; then
  efibootmgr -c -d /dev/${DEVX} -p \$(lsblk -nlpo name,label,partlabel | sed -n '/ESP/ s|.*[sv]da\([0-9]*\).*|\1|p') -l "/EFI/\${ID}/grubaa64.efi" -L \${ID}
  efibootmgr -c -d /dev/${DEVX} -p \$(lsblk -nlpo name,label,partlabel | sed -n '/ESP/ s|.*[sv]da\([0-9]*\).*|\1|p') -l "/EFI/BOOT/BOOTAA64.EFI" -L Default
else
  efibootmgr -c -d /dev/${DEVX} -p \$(lsblk -nlpo name,label,partlabel | sed -n '/ESP/ s|.*[sv]da\([0-9]*\).*|\1|p') -l "/EFI/\${ID}/grubx64.efi" -L \${ID}
  efibootmgr -c -d /dev/${DEVX} -p \$(lsblk -nlpo name,label,partlabel | sed -n '/ESP/ s|.*[sv]da\([0-9]*\).*|\1|p') -l "/EFI/BOOT/BOOTX64.EFI" -L Default
fi
efibootmgr -v ; sleep 3

mkpasswd -m help ; sleep 10

exit

EOFchroot

  . /mnt/etc/os-release
  snapshot_name=${ID}_${VERSION}-$(date -u "+%Y%m%d")

  if [ "zfs" = "${VOL_MGR}" ] ; then
    zfs snapshot ${ZPOOLNM}/ROOT/default@${snapshot_name} ;
    # example remove: zfs destroy ospool0/ROOT/default@snap1
    zfs list -t snapshot ; sleep 5 ;

    zpool trim ${ZPOOLNM} ; zpool set autotrim=on ${ZPOOLNM} ;
  else
    if [ "btrfs" = "${VOL_MGR}" ] ; then
      btrfs subvolume snapshot /mnt /mnt/.snapshots/${snapshot_name} ;
      # example remove: btrfs subvolume delete /.snapshots/snap1
      btrfs subvolume list /mnt ;
    elif [ "lvm" = "${VOL_MGR}" ] ; then
      lvcreate --snapshot --size 2G --name ${snapshot_name} ${GRP_NM}/osRoot ;
      # example remove: lvremove vg0/snap1
      lvs ;
    fi ;
    sleep 5 ; fstrim -av ;
  fi
  sync
}

unmount_reboot() {
  read -p "Enter 'y' if ready to unmount & reboot [yN]: " response
  if [ "y" = "${response}" ] || [ "Y" = "${response}" ] ; then
    sync ; swapoff -va ; umount -vR /mnt ;
    if [ "zfs" = "${VOL_MGR}" ] ; then
      #zfs umount -a ; zpool export -a ;
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
  kernel_bootloader
  unmount_reboot
}

#----------------------------------------
${@}
