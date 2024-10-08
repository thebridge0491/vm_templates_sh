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
export GRP_NM=${GRP_NM:-vg0}
export MIRROR=${MIRROR:-mirrors.kernel.org/mageia}
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
  if command -v dnf > /dev/null ; then
    #${DNFCMD} --nogpgcheck --installroot=/mnt --repofrompath=quickrepo${RELEASE},http://${MIRROR}/distrib/${RELEASE}/${UNAME_M}/media/core/release/ --repo=quickrepo${RELEASE} install -y urpmi dnf dnf-plugins-core locales-en ;
    ${DNFCMD} --nogpgcheck --installroot=/mnt config-manager -y --add-repo http://${MIRROR}/distrib/${RELEASE}/${UNAME_M}/media/core/release ;
    ${DNFCMD} --installroot=/mnt check-update -y ;
    ${DNFCMD} --nogpgcheck --installroot=/mnt install -y basesystem-minimal-core urpmi dnf dnf-plugins-core makedev ;
    ${DNFCMD} --installroot=/mnt repolist -y ;
  elif command -v yum-config-manager > /dev/null ; then
    rm -r /mnt/var/lib/rpm /mnt/var/cache/dnf ;
    mkdir -p /mnt/var/lib/rpm /mnt/var/cache/dnf ;
    rpm -v --root /mnt --initdb ;
    #repos_ver=$(curl -Ls http://${MIRROR}/distrib/${RELEASE}/${UNAME_M}/media/core/release | sed -n 's|.*mageia-repos-\(.*\).rpm.*|\1|p') ;
    # [wget -O file url | curl -Lo file url]
    #wget -O /tmp/repos.rpm http://${MIRROR}/distrib/${RELEASE}/${UNAME_M}/media/core/release/mageia-repos-${repos_ver:9-2.mga9.${UNAME_M}}.rpm ;
    #rpm -v -qip /tmp/repos.rpm ; sleep 5 ;
    #rpm -v --root /mnt --nodeps -i /tmp/repos.rpm ;
    yum-config-manager --releasever=${RELEASE} --nogpgcheck --installroot=/mnt -y --add-repo http://${MIRROR}/distrib/${RELEASE}/${UNAME_M}/media/core/release ;
    ${YUMCMD} --installroot=/mnt check-update -y ;
    ${YUMCMD} --nogpgcheck --installroot=/mnt install -y basesystem-minimal-core urpmi dnf dnf-plugins-core makedev ;
    ${YUMCMD} --installroot=/mnt repolist -y ;
  elif command -v urpmi > /dev/null ; then
    #urpmi.addmedia --urpmi-root /mnt --distrib --mirrorlist '${MIRRORLIST}'
    urpmi.addmedia --urpmi-root /mnt --distrib http://${MIRROR}/distrib/${RELEASE}/${UNAME_M} ;
    urpmi.update --urpmi-root /mnt -a ;
    urpmi --no-recommends --auto --urpmi-root /mnt basesystem-minimal-core urpmi dnf dnf-plugins-core makedev ;
    urpmq --list-url ;
  fi

  echo "Prepare chroot (mount --[r]bind devices)" ; sleep 3
  cp /etc/mtab /mnt/etc/mtab
  mkdir -p /mnt/dev /mnt/proc /mnt/sys /mnt/run
  mount --rbind /proc /mnt/proc ; mount --rbind /sys /mnt/sys
  mount --rbind /dev /mnt/dev

  mount --rbind /dev/pts /mnt/dev/pts ; mount --rbind /run /mnt/run
  modprobe efivarfs
  mount -t efivarfs efivarfs /mnt/sys/firmware/efi/efivars/

  #mkdir -p /mnt/var/empty /mnt/var/lock/subsys /mnt/etc/sysconfig/network-scripts
  #cp /etc/sysconfig/network-scripts/ifcfg-${ifdev} /mnt/etc/sysconfig/network-scripts/ifcfg-${ifdev}.bak
  cp /etc/resolv.conf /mnt/etc/resolv.conf
  sleep 5
}

system_config() {
export INIT_HOSTNAME=${1:-mageia-boxv0000}
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
#cd /dev ; MAKEDEV generic


echo "Config pkg repo mirror(s)" ; sleep 3
. /etc/os-release
#urpmi.update -a
##urpmi.addmedia --distrib --mirrorlist '${MIRRORLIST}'
#urpmi.addmedia --distrib http://${MIRROR}/distrib/\${VERSION_ID}/${UNAME_M}
#urpmq --list-url ; sleep 5
${DNFCMD} config-manager --set-enabled \${ID}-${UNAME_M} updates-${UNAME_M}
${DNFCMD} --refresh distro-sync -y
#cat /etc/yum.repos.d/* ; sleep 5
${DNFCMD} repolist -y enabled ; sleep 5


echo "Add software package selection(s)" ; sleep 3
pkgs_nms="basesystem-minimal locales-en sudo whois dhcp-client man-pages dosfstools xfsprogs openssh-server nano mandi-ifw shorewall shorewall-ipv6 urpmi dnf dnf-plugins-core harddrake-ui systemd" # task-xfce"
#urpmi.update -a
${DNFCMD} check-update -y
for pkgX in \${pkgs_nms} ; do
  #urpmi --no-recommends --auto \${pkgX} ;
  ${DNFCMD} install -y \${pkgX} ;
done
${DNFCMD} check-update -y
${DNFCMD} install -y 'dnf-command(versionlock)'


echo "Config keyboard ; localization" ; sleep 3
kbd_mode -u ; loadkeys us
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
#resolvconf -u
#sh -c 'cat >> /etc/resolv.conf' << EOF
##search hqdom.local
#nameserver 8.8.8.8
#
#EOF

cat /etc/resolv.conf ; sleep 5
sed -i '/127.0.1.1/d' /etc/hosts
echo "127.0.1.1    ${INIT_HOSTNAME}.localdomain    ${INIT_HOSTNAME}" >> /etc/hosts

ifdev=\$(ip -o link | grep 'link/ether' | grep 'LOWER_UP' | sed -n 's|\S*: \(\w*\):.*|\1|p')

#sh -c "cat >> /etc/sysconfig/network-scripts/ifcfg-\${ifdev}" << EOF
#BOOTPROTO=dhcp
#STARTMODE=auto
#ONBOOT=yes
##DHCP_CLIENT=dhclient
#
#EOF
sh -c "cat >> /etc/sysconfig/network" << EOF
NETWORKING=yes
CRDA_DOMAIN=US
HOSTNAME=${INIT_HOSTNAME}

EOF


echo "Update services" ; sleep 3
#drakfirewall ; sleep 5
service shorewall stop ; service shorewall6 stop
systemctl disable shorewall ; systemctl disable shorewall6
service -s ; service --status-all ; sleep 5
systemctl enable sshd


echo "Set root passwd ; add user" ; sleep 3
groupadd --system wheel
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


sed -i "/^%wheel.*(ALL)\s*ALL/ s|%wheel|# %wheel|" /etc/sudoers
sed -i "/^#.*%wheel.*NOPASSWD.*/ s|^#.*%wheel|%wheel|" /etc/sudoers
echo '%wheel ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers
sed -i "s|^[^#].*requiretty|# Defaults requiretty|" /etc/sudoers

${DNFCMD} clean -y all

exit

EOFchroot
# end chroot commands
}

kernel_bootloader() {
  # LANG=[C|en_US].UTF-8
  cat << EOFchroot | LANG=C.UTF-8 LANGUAGE=en chroot /mnt /bin/sh
set -x

. /etc/os-release
#urpmi.update -a
${DNFCMD} check-update -y

pkgs_nms="basesystem kernel-desktop-latest microcode_ctl grub grub2-efi efibootmgr"
for pkgX in \${pkgs_nms} ; do
  #urpmi --no-recommends --auto \${pkgX} ;
  ${DNFCMD} install -y \${pkgX} ;
done

modprobe vfat ; lsmod | grep -e fat ; sleep 5

if [ "btrfs" = "${VOL_MGR}" ] ; then
  #urpmi --no-recommends --auto btrfs-progs ;
  ${DNFCMD} install -y btrfs-progs ;
  modprobe btrfs ; sleep 5 ;
elif [ "lvm" = "${VOL_MGR}" ] ; then
  #urpmi --no-recommends --auto lvm2 ;
  ${DNFCMD} install -y lvm2 ;
  # cryptsetup
  modprobe dm-mod ; vgscan ; vgchange -ay ; lvs ; sleep 5 ;
fi

echo "Config dracut"
echo 'hostonly="yes"' >> /etc/dracut.conf
mkdir -p /etc/dracut.conf.d
kver="\$(ls -A /lib/modules/ | tail -1)" # or ? $(uname -r)
#mkinitrd /boot/initrd-\${kver} \${kver}
dracut --force --kver \${kver}


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
sed -i '/GRUB_CMDLINE_LINUX_DEFAULT/ s|="\(.*\)"|="\1 text xdriver=vesa nomodeset rootdelay=5 resume=/dev/foo"|'  \
  /etc/default/grub

if [ "btrfs" = "${VOL_MGR}" ] ; then
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

whois-mkpasswd -m help ; sleep 10

exit

EOFchroot
# end chroot commands

  . /mnt/etc/os-release
  snapshot_name=${ID}_${VERSION}-$(date -u "+%Y%m%d")

  if [ "btrfs" = "${VOL_MGR}" ] ; then
    btrfs subvolume snapshot /mnt /mnt/.snapshots/${snapshot_name} ;
    # example remove: btrfs subvolume delete /.snapshots/snap1
    btrfs subvolume list /mnt ;
  elif [ "lvm" = "${VOL_MGR}" ] ; then
    lvcreate --snapshot --size 2G --name ${snapshot_name} ${GRP_NM}/osRoot ;
    # example remove: lvremove vg0/snap1
    lvs ;
  fi
  sleep 5 ; fstrim -av
  sync
}

unmount_reboot() {
  read -p "Enter 'y' if ready to unmount & reboot [yN]: " response
  if [ "y" = "${response}" ] || [ "Y" = "${response}" ] ; then
    sync ; swapoff -va ; umount -vR /mnt ;
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
