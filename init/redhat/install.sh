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
# [rocky/8|almalinux/8|centos/8-stream]/BaseOS/x86_64/os | centos/7/os/x86_64]
# (rocky) mirror: dl.rockylinux.org/pub/rocky
# (almalinux) mirror: repo.almalinux.org/almalinux
# (centos[-stream]) mirror: mirror.centos.org/centos
export MIRROR=${MIRROR:-dl.rockylinux.org/pub/rocky}
export RELEASE=${RELEASE:-9}
export UNAME_M=$(uname -m)

export YUMCMD="yum --setopt=requires_policy=strong --setopt=group_package_types=mandatory --releasever=${RELEASE}"
export DNFCMD="dnf --setopt=install_weak_deps=False --releasever=${RELEASE}"


# ifconfig [;ifconfig wlan create wlandev ath0 ; ifconfig wlan0 up scan]
# networkctl status ; networkctl up {ifdev}
# nmcli device status ; nmcli connection up {ifdev}

#ifdev=$(ip -o link | grep 'link/ether' | grep 'LOWER_UP' | sed -n 's|\S*: \(\w*\):.*|\1|p')


bootstrap() {
  echo "Bootstrap base pkgs" ; sleep 3
  if [ "zfs" = "$VOL_MGR" ] ; then
    zfs umount $ZPOOLNM/var/mail ; zfs destroy $ZPOOLNM/var/mail ;
  fi
  if [ "7" = "${RELEASE}" ] ; then
    REPO_DIRECTORY="/${RELEASE}/os/${UNAME_M}" ;
  else
    REPO_DIRECTORY="/${RELEASE}/BaseOS/${UNAME_M}/os" ;
  fi
  if command -v dnf > /dev/null ; then
    #${DNFCMD} --nogpgcheck --installroot=/mnt --repofrompath=quickrepo${RELEASE},http://${MIRROR}${REPO_DIRECTORY}/ --repo=quickrepo${RELEASE} install -y basesystem bash dnf dnf-plugins-core yum yum-utils ;
    ${DNFCMD} --nogpgcheck --installroot=/mnt config-manager -y --add-repo http://${MIRROR}${REPO_DIRECTORY} ;
    ${DNFCMD} --installroot=/mnt check-update -y ;
    ${DNFCMD} --nogpgcheck --installroot=/mnt install -y basesystem bash dnf dnf-plugins-core yum yum-utils ;
    ${DNFCMD} --installroot=/mnt repolist -y ;
  elif command -v yum-config-manager > /dev/null ; then
    rm -r /mnt/var/lib/rpm /mnt/var/cache/dnf ;
    mkdir -p /mnt/var/lib/rpm /mnt/var/cache/dnf ;
    rpm -v --root /mnt --initdb ;
    # [wget -O file url | curl -Lo file url]
    #wget -O /tmp/repos.rpm http://${MIRROR}${REPO_DIRECTORY}/Packages/centos-stream-repos-9.0-18.el9.noarch.rpm ;
    #rpm -v -qip /tmp/repos.rpm ; sleep 5 ;
    #rpm -v --root /mnt --nodeps -i /tmp/repos.rpm ;
    yum-config-manager --releasever=${RELEASE} --nogpgcheck --installroot=/mnt -y --add-repo http://${MIRROR}${REPO_DIRECTORY} ;
    ${YUMCMD} --installroot=/mnt check-update -y ;
    ${YUMCMD} --nogpgcheck --installroot=/mnt install -y basesystem bash dnf dnf-plugins-core yum yum-utils ;
    ${YUMCMD} --installroot=/mnt repolist -y ;
  fi
  sleep 5

  echo "Prepare chroot (mount --[r]bind devices)" ; sleep 3
  cp /etc/mtab /mnt/etc/mtab
  mkdir -p /mnt/dev /mnt/proc /mnt/sys /mnt/run
  mount --rbind /proc /mnt/proc ; mount --rbind /sys /mnt/sys
  mount --rbind /dev /mnt/dev

  mount --rbind /dev/pts /mnt/dev/pts ; mount --rbind /run /mnt/run
  modprobe efivarfs
  mount -t efivarfs efivarfs /mnt/sys/firmware/efi/efivars/

  ## temporarily disable SELinux to allow chpasswd in chroot
  #setenforce 0 ; sestatus ; sleep 5

  #mkdir -p /mnt/var/empty /mnt/var/lock/subsys /mnt/etc/sysconfig/network-scripts
  #cp /etc/sysconfig/network-scripts/ifcfg-$ifdev /mnt/etc/sysconfig/network-scripts/ifcfg-${ifdev}.bak
  cp /etc/resolv.conf /mnt/etc/resolv.conf
  sleep 5
}

system_config() {
  export INIT_HOSTNAME=${1:-redhat-boxv0000}
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
##cd /dev ; MAKEDEV generic


echo "Config pkg repo mirror(s)" ; sleep 3
. /etc/os-release ; echo \${VERSION_ID} ; sleep 3
VERSION_MAJOR=\$(echo \${VERSION_ID} | cut -d. -f1)
##yum-config-manager --add-repo http://mirrorlist.centos.org/?release=${RELEASE}&arch=${UNAME_M}&repo=baseos
#yum-config-manager --add-repo http://${MIRROR}/${RELEASE}/BaseOS/${UNAME_M}/os
#yum-config-manager --add-repo http://${MIRROR}/${RELEASE}/AppStream/${UNAME_M}/os
#yum-config-manager --add-repo http://${MIRROR}/${RELEASE}/extras/${UNAME_M}/os

${DNFCMD} check-update -y
${DNFCMD} reinstall -y dnf dnf-plugins-core yum yum-utils 'dnf-command(config-manager)'
${DNFCMD} install -y dnf dnf-plugins-core yum yum-utils 'dnf-command(config-manager)'
${DNFCMD} config-manager -y --set-enabled crb
${DNFCMD} install -y epel-release
${DNFCMD} install -y http://dl.fedoraproject.org/pub/epel/epel-release-latest-\${VERSION_MAJOR}.noarch.rpm
# Release version errors w/ CentOS Stream for EPEL/EPEL Modular
${DNFCMD} config-manager -y --set-disabled epel epel-modular
${DNFCMD} config-manager -y --set-disabled epel
#cat /etc/yum.repos.d/* ; sleep 5
${DNFCMD} repolist -y ; sleep 5


echo "Add software package selection(s)" ; sleep 3
${DNFCMD} install -y @core sudo tar kbd openssl systemd
# @xfce-desktop
# @^minimal @minimal-environment redhat-lsb-core

${DNFCMD} install -y network-scripts dhcp-client
${DNFCMD} install -y NetworkManager-initscripts-updown dhcp-client

${DNFCMD} check-update -y
${DNFCMD} install -y 'dnf-command(versionlock)'

${DNFCMD} install -y openssh-clients openssh-server
systemctl stop sshd ; systemctl enable sshd


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
sh -c "cat >> /etc/sysconfig/network-scripts/ifcfg-\$ifdev" << EOF
BOOTPROTO=dhcp
STARTMODE=auto
ONBOOT=yes
DHCP_CLIENT=dhclient

EOF

sh -c "cat >> /etc/sysconfig/network" << EOF
NETWORKING=yes
CRDA_DOMAIN=US
HOSTNAME=${INIT_HOSTNAME}

EOF


echo "Set root passwd ; add user" ; sleep 3
#echo -n "root:${PASSWD_PLAIN}" | chpasswd
echo -n 'root:${PASSWD_CRYPTED}' | chpasswd -e

DIR_MODE=0750 useradd -m -G wheel -s /bin/bash -c 'Packer User' packer
#echo -n "packer:${PASSWD_PLAIN}" | chpasswd
echo -n 'packer:${PASSWD_CRYPTED}' | chpasswd -e
chown -R packer:\$(id -gn packer) /home/packer

#sh -c 'cat >> /etc/sudoers.d/99_packer' << EOF
#Defaults:packer !requiretty
#\$(id -un packer) ALL=(ALL) NOPASSWD: ALL
#EOF
#chmod 0440 /etc/sudoers.d/99_packer


sed -i "/^%wheel.*(ALL)\s*ALL/ s|%sudo|# %sudo|" /etc/sudoers
#sed -i "/^#.*%wheel.*NOPASSWD.*/ s|^#.*%wheel|%wheel|" /etc/sudoers
echo '%wheel ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers
sed -i "s|^[^#].*requiretty|# Defaults requiretty|" /etc/sudoers


echo "Config SELinux" ; sleep 3
touch /.autorelabel
sed -i 's|SELINUX=.*$|SELINUX=permissive|' /etc/sysconfig/selinux
sestatus ; sleep 5


${DNFCMD} clean -y all

exit

EOFchroot
# end chroot commands
}

kernel_bootloader() {
# LANG=[C|en_US].UTF-8
cat << EOFchroot | LANG=C.UTF-8 LANGUAGE=en chroot /mnt /bin/sh
set -x

. /etc/os-release ; VERSION_MAJOR=\$(echo \${VERSION_ID} | cut -d. -f1)
${DNFCMD} check-update -y

# Use EL release kernel packages (avoid dkms build errors)
if [ "7" = "\${VERSION_MAJOR}" ] ; then
  ${DNFCMD} --enablerepo=epel install -y kernel kernel-devel ;
else
  ${DNFCMD} --enablerepo=epel --enablerepo=epel-modular install -y kernel kernel-devel ;
  ${DNFCMD} --enablerepo=epel install -y kernel kernel-devel ;
fi

${DNFCMD} install -y linux-firmware shim-* grub2-* efibootmgr
if [ "x86_64" = "${UNAME_M}" ] ; then
  ${DNFCMD} install -y microcode_ctl ;
fi
#${DNFCMD} install -y dracut-tools dracut-config-generic dracut-config-rescue

kver=\$(${DNFCMD} list -y --installed kernel | sed -n 's|kernel[a-z0-9._]*[ ]*\([^ ]*\)[ ]*.*$|\1|p' | tail -n1)
echo \$kver ; sleep 5


echo "Config dracut"
echo 'hostonly="yes"' >> /etc/dracut.conf
mkdir -p /etc/dracut.conf.d

if [ "zfs" = "$VOL_MGR" ] ; then
  ${DNFCMD} install -y dracut-tools dracut-config-generic dracut-config-rescue ;

  ## for centos-stream VERSION_ID=8, not similar 8.4
  ## get zfs-release version from EL release kernel
  if [ $(echo ${RELEASE} | grep -e '-stream') ] ; then
    #ZFS_REL=${ZFS_REL:-8_4} ; echo \${ZFS_REL} ;
    ZFS_REL=\$(echo \$kver | sed 's|.*\.el\(.*\)$|\1|') ; echo \${ZFS_REL} ;
  fi ;
  sleep 3 ;

  ${DNFCMD} install -y http://download.zfsonlinux.org/epel/zfs-release.el${ZFS_REL:-\${VERSION_ID/./_}}.noarch.rpm ;
  ${DNFCMD} install -y http://download.zfsonlinux.org/epel/zfs-release-2-2.el\${VERSION_MAJOR}.noarch.rpm ;
  #${DNFCMD} install -y http://download.zfsonlinux.org/epel/zfs-release-2-2\$(rpm --eval "%{dist}").noarch.rpm ;
  rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-zfsonlinux ;
  ${DNFCMD} repolist -y ; sleep 5 ;
  #${DNFCMD} config-manager -y --set-disabled zfs ;
  ${DNFCMD} --enablerepo=epel --enablerepo=epel-modular --enablerepo=zfs install -y zfs zfs-dracut ;
  ${DNFCMD} --enablerepo=epel --enablerepo=zfs install -y zfs zfs-dracut ;
  sleep 3 ;

  mkdir -p /etc/dkms ; echo REMAKE_INITRD=yes > /etc/dkms/zfs.conf ;
  dkms status ; modprobe zfs ; zfs version ; sleep 5 ;

  zgenhostid -f -o /etc/hostid ; sleep 5 ;

  systemctl preset zfs-import.target ; systemctl preset zfs-mount
  systemctl preset zfs.target ; systemctl preset zfs-zed ;
  systemctl preset zfs-import-cache ;

  systemctl enable zfs-import-cache ; systemctl enable zfs-import.target ;
  systemctl enable zfs-mount ; systemctl enable zfs.target ;
  sleep 10 ;

  echo 'nofsck="yes"' >> /etc/dracut.conf.d/zol.conf ;
  echo 'add_dracutmodules+=" zfs "' >> /etc/dracut.conf.d/zol.conf ;
  echo 'omit_dracutmodules+=" btrfs resume "' >> /etc/dracut.conf.d/zol.conf ;

  echo zfs > /etc/modules-load.d/zfs.conf ; # ??

  echo "Hold zfs & kernel package upgrades (require manual upgrade)" ;
  ${DNFCMD} versionlock -y add zfs zfs-dkms zfs-dracut kernel kernel-core \
    kernel-modules kernel-tools kernel-tools-libs kernel-devel kernel-headers ;
  ${DNFCMD} versionlock -y list ; sleep 3 ;
elif [ "lvm" = "$VOL_MGR" ] ; then
  ${DNFCMD} install -y lvm2 ;
  # cryptsetup
  modprobe dm-mod ; vgscan ; vgchange -ay ; lvs ; sleep 5 ;
fi

dracut --force --kver \$kver.${UNAME_M}


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
  grub2-install --target=i386-pc --recheck /dev/$DEVX ;
  cp -R /boot/efi/EFI/\${ID}/* /boot/efi/EFI/BOOT/ ;
  cp /boot/efi/EFI/BOOT/BOOTX64.EFI /boot/efi/EFI/BOOT/BOOTX64.EFI.bak ;
  cp /boot/efi/EFI/BOOT/grubx64.EFI /boot/efi/EFI/BOOT/BOOTX64.EFI ;
  #cp /boot/efi/EFI/\${ID}/grubx64.efi /boot/efi/EFI/BOOT/BOOTX64.EFI ;
fi

sh -c 'cat >> /etc/default/grub' << EOF
GRUB_TIMEOUT=5
GRUB_DISTRIBUTOR="\$(sed 's, release .*$,,g' /etc/system-release)"
GRUB_DEFAULT=saved
GRUB_DISABLE_SUBMENU=false
GRUB_TERMINAL_OUTPUT="console"
GRUB_CMDLINE_LINUX="crashkernel=auto rd.auto consoleblank=0 selinux=1 enforcing=0"
GRUB_CMDLINE_LINUX_DEFAULT=""
GRUB_DISABLE_RECOVERY="false"

EOF

#sed -i -e "s|^GRUB_TIMEOUT=.*$|GRUB_TIMEOUT=1|" /etc/default/grub
#sed -i -e "/GRUB_DEFAULT/ s|=.*$|=saved|" /etc/default/grub
#echo "GRUB_SAVEDEFAULT=true" >> /etc/default/grub
#echo "#GRUB_CMDLINE_LINUX='cryptdevice=/dev/sda2:cryptroot'" >> /etc/default/grub
sed -i '/GRUB_CMDLINE_LINUX_DEFAULT/ s|="\(.*\)"|="\1 text xdriver=vesa nomodeset rootdelay=5"|'  \
  /etc/default/grub

if [ "zfs" = "$VOL_MGR" ] ; then
  sed -i -e '/GRUB_CMDLINE_LINUX_DEFAULT/ s|nomodeset rootdelay|nomodeset root=ZFS=${ZPOOLNM}/ROOT/default rootdelay|' /etc/default/grub ;
  echo 'GRUB_PRELOAD_MODULES="zfs"' >> /etc/default/grub ;
elif [ "btrfs" = "$VOL_MGR" ] ; then
  echo 'GRUB_PRELOAD_MODULES="btrfs"' >> /etc/default/grub ;
elif [ "lvm" = "$VOL_MGR" ] ; then
  echo 'GRUB_PRELOAD_MODULES="lvm"' >> /etc/default/grub ;
fi

if [ "\$(dmesg | grep -ie 'Hypervisor detected')" ] ; then
  sed -i -e '/GRUB_CMDLINE_LINUX_DEFAULT/ s|="\(.*\)"|="\1 net.ifnames=0 biosdevname=0"|' /etc/default/grub ;
fi
grub2-mkconfig -o /boot/efi/EFI/\${ID}/grub.cfg
cp -f /boot/efi/EFI/\${ID}/grub.cfg /boot/grub2/grub.cfg
cp -f /boot/efi/EFI/\${ID}/grub.cfg /boot/efi/EFI/BOOT/grub.cfg

if [ "aarch64" = "${UNAME_M}" ] ; then
  efibootmgr -c -d /dev/$DEVX -p \$(lsblk -nlpo name,label,partlabel | sed -n '/ESP/ s|.*[sv]da\([0-9]*\).*|\1|p') -l "/EFI/\${ID}/grubaa64.efi" -L \${ID}
  efibootmgr -c -d /dev/$DEVX -p \$(lsblk -nlpo name,label,partlabel | sed -n '/ESP/ s|.*[sv]da\([0-9]*\).*|\1|p') -l "/EFI/BOOT/BOOTAA64.EFI" -L Default
else
  efibootmgr -c -d /dev/$DEVX -p \$(lsblk -nlpo name,label,partlabel | sed -n '/ESP/ s|.*[sv]da\([0-9]*\).*|\1|p') -l "/EFI/\${ID}/grubx64.efi" -L \${ID}
  efibootmgr -c -d /dev/$DEVX -p \$(lsblk -nlpo name,label,partlabel | sed -n '/ESP/ s|.*[sv]da\([0-9]*\).*|\1|p') -l "/EFI/BOOT/BOOTX64.EFI" -L Default
fi
efibootmgr -v ; sleep 3

${DNFCMD} install -y mkpasswd
mkpasswd -m help ; sleep 10

exit

EOFchroot

  . /mnt/etc/os-release
  snapshot_name=${ID}_install-$(date "+%Y%m%d")

  if [ "zfs" = "$VOL_MGR" ] ; then
    zfs snapshot ${ZPOOLNM}/ROOT/default@${snapshot_name} ;
    # example remove: zfs destroy ospool0/ROOT/default@snap1
    zfs list -t snapshot ; sleep 5 ;

    zpool trim ${ZPOOLNM} ; zpool set autotrim=on ${ZPOOLNM} ;
  else
    if [ "lvm" = "$VOL_MGR" ] ; then
      lvcreate --snapshot --size 2G --name ${snapshot_name} ${GRP_NM}/osRoot ;
      lvs ;
    fi ;
    sleep 5 ; fstrim -av ;
  fi
  sync
}

unmount_reboot() {
  read -p "Enter 'y' if ready to unmount & reboot [yN]: " response
  if [ "y" = "$response" ] || [ "Y" = "$response" ] ; then
    sync ; swapoff -va ; umount -vR /mnt ;
    if [ "zfs" = "$VOL_MGR" ] ; then
      #zfs umount -a ; zpool export -a ;
      zfs umount -a ; zpool export $ZPOOLNM ;
    fi ;
    reboot ; #poweroff ;
  fi
}

run_install() {
  INIT_HOSTNAME=${1:-}
  #PASSWD_PLAIN=${2:-}
  PASSWD_CRYPTED=${2:-}

  bootstrap
  system_config $INIT_HOSTNAME $PASSWD_CRYPTED
  kernel_bootloader
  unmount_reboot
}

#----------------------------------------
$@
