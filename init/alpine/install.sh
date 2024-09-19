#!/bin/sh -x

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
export MIRROR=${MIRROR:-dl-cdn.alpinelinux.org/alpine}
export RELEASE=${RELEASE:-latest-stable}
export UNAME_M=$(uname -m)


# ip link ; udhcpc -i eth0 #; iw dev

#ifdev=$(ip -o link | grep 'link/ether' | grep 'LOWER_UP' | sed -n 's|\S*: \(\w*\):.*|\1|p')


bootstrap() {
  echo "Bootstrap base pkgs" ; sleep 3
  if command -v apk > /dev/null ; then
    apk --arch ${UNAME_M} --repository http://${MIRROR}/${RELEASE}/main --update-cache --allow-untrusted --root /mnt --initdb add alpine-base tzdata ;
  else
    apktools_ver=$(curl -Ls http://${MIRROR}/${RELEASE}/main/${UNAME_M} | sed -n 's|.*apk-tools-static-\(.*\).apk.*|\1|p') ;
    curl -LO http://${MIRROR}/${RELEASE}/main/${UNAME_M}/apk-tools-static-${apktools_ver:-2.12.10-r1}.apk ;
    tar -xf apk-tools-static-*.apk ;
    ./sbin/apk.static --arch ${UNAME_M} --repository http://${MIRROR}/${RELEASE}/main --update-cache --allow-untrusted --root /mnt --initdb add alpine-base tzdata ;
  fi


  echo "Prepare chroot (mount --[r]bind devices)" ; sleep 3
  cp /etc/mtab /mnt/etc/mtab
  mkdir -p /mnt/dev /mnt/proc /mnt/sys /mnt/run
  mount --rbind /proc /mnt/proc ; mount --rbind /sys /mnt/sys
  mount --rbind /dev /mnt/dev

  mount --rbind /dev/pts /mnt/dev/pts ; mount --rbind /run /mnt/run
  modprobe efivarfs
  mount -t efivarfs efivarfs /mnt/sys/firmware/efi/efivars/


  cp /etc/resolv.conf /mnt/etc/resolv.conf ; mkdir -p /mnt/root
  mkdir -p /mnt/etc/apk ; cp /etc/apk/repositories /mnt/etc/apk/
  sleep 5
}

system_config() {
  export INIT_HOSTNAME=${1:-alpine-boxv0000}
  #export PASSWD_PLAIN=${2:-packer}
  export PASSWD_CRYPTED=${2:-\$6\$16CHARACTERSSALT\$A4i3yeafzCxgDj5imBx2ZdMWnr9LGzn3KihP9Dz0zTHbxw31jJGEuuJ6OB6Blkkw0VSUkQzSjE9n4iAAnl0RQ1}

  cat << EOFchroot | LANG=en_US.UTF-8 LANGUAGE=en chroot /mnt /bin/sh
set -x

chmod 1777 /tmp ; chmod 1777 /var/tmp
chown root:root / ; chmod 0755 /

unset LC_ALL
export TERM=xterm-color     # xterm | xterm-color
#hostname ${INIT_HOSTNAME}

ls /proc ; sleep 5 ; ls /dev ; sleep 5

. /etc/os-release
#RELEASE=\$(cat /etc/alpine-release | cut -d. -f1-2)
sed -i '/cdrom/ s|^|#|' /etc/apk/repositories
#echo "http://${MIRROR}/v\${RELEASE}/main" >> /etc/apk/repositories
echo "http://${MIRROR}/${RELEASE}/main" >> /etc/apk/repositories
echo "http://${MIRROR}/${RELEASE}/community" >> /etc/apk/repositories
apk --arch ${UNAME_M} update
cat /etc/apk/repositories ; sleep 5


echo "Add software package selection(s)" ; sleep 3
apk --arch ${UNAME_M} add tzdata sudo mkpasswd dosfstools e2fsprogs xfsprogs dhcp bash util-linux shadow openssh multipath-tools
#apk --arch ${UNAME_M} add xfce4
sleep 5


echo "Config keyboard ; localization" ; sleep 3
kbd_mode -u ; loadkeys us
sed -i -e '/en_US.UTF-8 UTF-8/ s|^# ||' /etc/locale.gen
echo 'LANG=en_US.UTF-8' > /etc/locale.conf
echo "en_US.UTF-8 UTF-8" >> /etc/default/libc-locales
locale-gen


echo "Config time zone & clock" ; sleep 3
ln -sf /usr/share/zoneinfo/UTC /etc/localtime
hwclock --systohc --utc


echo "Config hostname ; network" ; sleep 3
echo "${INIT_HOSTNAME}" > /etc/hostname
#resolvconf -u   # generates /etc/resolv.conf
cat /etc/resolv.conf ; sleep 5
sed -i '/127.0.1.1/d' /etc/hosts
echo "127.0.1.1    ${INIT_HOSTNAME}.localdomain    ${INIT_HOSTNAME}" >> /etc/hosts

ifdev=\$(ip -o link | grep 'link/ether' | grep 'LOWER_UP' | sed -n 's|\S*: \(\w*\):.*|\1|p')

sh -c 'cat > /etc/network/interfaces' << EOF
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp

EOF


echo "Update services" ; sleep 3
for svc_runlvl in devfs:sysinit dmesg:sysinit mdev:sysinit hwdrivers:sysinit \
    networking:boot urandom:boot hostname:boot hwclock:boot modules:boot \
    sysctl:boot bootmisc:boot syslog:boot swap:boot loadkmap:boot \
    mount-ro:shutdown killprocs:shutdown savecache:shutdown \
    acpid:default sshd:default crond:default ; do
    # udev:sysinit udev-postmount:default udev-trigger:sysinit ; do
  svc=\$(echo \${svc_runlvl} | cut -d: -f1) ;
  runlvl=\$(echo \${svc_runlvl} | cut -d: -f2) ;

  rc-update add \${svc} \${runlvl} ;
done


echo "Set root passwd ; add user" ; sleep 3
#echo -n "root:${PASSWD_PLAIN}" | chpasswd
echo -n 'root:${PASSWD_CRYPTED}' | chpasswd -e

#DIR_MODE=0750
useradd -m -g users -G wheel -s /bin/bash -c 'Packer User' packer
#echo -n "packer:${PASSWD_PLAIN}" | chpasswd
echo -n 'packer:${PASSWD_CRYPTED}' | chpasswd -e
chown -R packer:\$(id -gn packer) /home/packer

#sh -c 'cat > /etc/sudoers.d/99_packer' << EOF
#Defaults:packer !requiretty
#\$(id -un packer) ALL=(ALL) NOPASSWD: ALL
#
#EOF
#chmod 0440 /etc/sudoers.d/99_packer
sleep 5


sed -i "/^%wheel.*(ALL)\s*ALL/ s|%wheel|# %wheel|" /etc/sudoers
sed -i "/^#.*%wheel.*NOPASSWD.*/ s|^#.*%wheel|%wheel|" /etc/sudoers
sed -i "s|^[^#].*requiretty|# Defaults requiretty|" /etc/sudoers

#echo "Temporarily permit root login via ssh password" ; sleep 3
#sed -i "/PermitRootLogin/ s|^\(.*\)$|PermitRootLogin yes|" /etc/ssh/sshd_config

apk --arch ${UNAME_M} -v cache clean

exit

EOFchroot
# end chroot commands
}

kernel_bootloader() {
  cat << EOFchroot | LANG=en_US.UTF-8 LANGUAGE=en chroot /mnt /bin/sh
set -x

. /etc/os-release

apk --arch ${UNAME_M} add linux-lts linux-lts-dev mkinitfs grub-efi efibootmgr
#apk --arch ${UNAME_M} add xfce4
if [ "x86_64" = "${UNAME_M}" ] ; then
  apk --arch ${UNAME_M} add grub-bios
fi
modprobe vfat ; lsmod | grep -e fat ; sleep 5

if [ "zfs" = "${VOL_MGR}" ] ; then
  apk --arch ${UNAME_M} add zfs ;
  modprobe zfs ; zfs version ; sleep 5 ;

  zgenhostid -f -o /etc/hostid ; sleep 5 ;

  for svc_runlvl in zfs-import:sysinit zfs-mount:sysinit ; do
    svc=\$(echo \${svc_runlvl} | cut -d: -f1) ;
    runlvl=\$(echo \${svc_runlvl} | cut -d: -f2) ;

    rc-update add \${svc} \${runlvl} ;
  done

  features="ata base cdrom ext4 xfs keymap kms mmc raid scsi usb virtio zfs network" ;

  #echo "Hold zfs & kernel package upgrades (require manual upgrade)" ;
  apk --arch ${UNAME_M} fix ; sleep 3 ;
  for pkgX in zfs zfs-lts zfs-openrc linux-lts linux-lts-dev ; do
    apk --arch ${UNAME_M} add \${pkgX}=\$(apk --arch ${UNAME_M} info -ve \${pkgX} | sed "s|\${pkgX}-\(.*\)|\1|") ;
  done ;
  # ?? how to display held/pinned packages ??
elif [ "btrfs" = "${VOL_MGR}" ] ; then
  apk --arch ${UNAME_M} add btrfs-progs ;
  modprobe btrfs ; sleep 5 ;

  cat << EOF >> /etc/init.d/btrfs-scan ;
#!/sbin/openrc-run

name="btrfs-scan"

depend() {
  before localmount
}

start() {
  /sbin/btrfs device scan
}

EOF
  chmod +x /etc/init.d/btrfs-scan ;

  for svc_runlvl in btrfs-scan:boot ; do
    svc=\$(echo \${svc_runlvl} | cut -d: -f1) ;
    runlvl=\$(echo \${svc_runlvl} | cut -d: -f2) ;

    rc-update add \${svc} \${runlvl} ;
  done

  features="ata base cdrom ext4 xfs keymap kms mmc raid scsi usb virtio btrfs network" ;
elif [ "lvm" = "${VOL_MGR}" ] ; then
  apk --arch ${UNAME_M} add lvm2 ;
  # cryptsetup
  modprobe dm-mod ; vgscan ; vgchange -ay ; lvs ; sleep 5 ;

  for svc_runlvl in lvm:boot ; do
    svc=\$(echo \${svc_runlvl} | cut -d: -f1) ;
    runlvl=\$(echo \${svc_runlvl} | cut -d: -f2) ;

    rc-update add \${svc} \${runlvl} ;
  done

  features="ata base cdrom ext4 xfs keymap kms mmc raid scsi usb virtio lvm network" ;
else
  features="ata base cdrom ext4 xfs keymap kms mmc raid scsi usb virtio network" ;
fi

echo "Config Linux kernel"
echo features=\""\${features}"\" > /etc/mkinitfs/mkinitfs.conf
kernel="\$(ls -A /lib/modules/ | tail -1)"
mkinitfs "\${kernel}"


grub-probe /boot

echo "Bootloader installation & config" ; sleep 3
mkdir -p /boot/efi/EFI/\${ID} /boot/efi/EFI/BOOT
if [ "aarch64" = "${UNAME_M}" ] ; then
  grub-install --target=arm64-efi --efi-directory=/boot/efi --bootloader-id=\${ID} --recheck --removable ;
  cp /boot/efi/EFI/\${ID}/grubaa64.efi /boot/efi/EFI/BOOT/BOOTAA64.EFI ;
else
  grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=\${ID} --recheck --removable ;
  grub-install --target=i386-pc --recheck /dev/${DEVX} ;
  cp /boot/efi/EFI/\${ID}/grubx64.efi /boot/efi/EFI/BOOT/BOOTX64.EFI ;
fi

#sed -i -e "s|^GRUB_TIMEOUT=.*$|GRUB_TIMEOUT=1|" /etc/default/grub
#sed -i -e '/GRUB_CMDLINE_LINUX_DEFAULT/ s|="\(.*\)"|="\1 rd.auto=1 text xdriver=vesa nomodeset rootdelay=5 modules=sd-mod,usb-storage,ext4"|' /etc/default/grub ;
echo 'GRUB_CMDLINE_LINUX_DEFAULT="rd.auto=1 text nomodeset rootdelay=5 modules=sd-mod,usb-storage,ext4"' >> /etc/default/grub ;
#sed -i -e '/GRUB_CMDLINE_LINUX_DEFAULT/ s|="\(.*\)"|="\1 video=1024x768 "|' /etc/default/grub

if [ "zfs" = "${VOL_MGR}" ] ; then
  sed -i -e '/GRUB_CMDLINE_LINUX_DEFAULT/ s|\(usb-storage,ext4\)|\1,zfs|' /etc/default/grub ;
  sed -i -e '/GRUB_CMDLINE_LINUX_DEFAULT/ s|nomodeset rootdelay|nomodeset root=ZFS=${ZPOOLNM}/ROOT/default rootdelay|' /etc/default/grub ;
  echo 'GRUB_PRELOAD_MODULES="zfs"' >> /etc/default/grub ;
elif [ "btrfs" = "${VOL_MGR}" ] ; then
  sed -i -e '/GRUB_CMDLINE_LINUX_DEFAULT/ s|\(usb-storage,ext4\)|\1,btrfs|' /etc/default/grub ;
  echo 'GRUB_PRELOAD_MODULES="btrfs"' >> /etc/default/grub ;
elif [ "lvm" = "${VOL_MGR}" ] ; then
  sed -i -e '/GRUB_CMDLINE_LINUX_DEFAULT/ s|\(usb-storage,ext4\)|\1,lvm|' /etc/default/grub ;
  echo 'GRUB_PRELOAD_MODULES="lvm"' >> /etc/default/grub ;
fi

if [ "\$(dmesg | grep -ie 'Hypervisor detected')" ] ; then
  sed -i -e '/GRUB_CMDLINE_LINUX_DEFAULT/ s|="\(.*\)"|="\1 net.ifnames=0 biosdevname=0"|' /etc/default/grub ;
fi
grub-mkconfig -o /boot/grub/grub.cfg

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
  snapshot_name=${ID}_${VERSION_ID}-$(date -u "+%Y%m%d")

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
