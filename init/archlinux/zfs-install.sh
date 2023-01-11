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

export GRP_NM=${GRP_NM:-vg0} ; export ZPOOLNM=${ZPOOLNM:-ospool0} ; UNAME_M=$(uname -m)
service_mgr=${service_mgr:-runit} # runit | openrc | s6

export INIT_HOSTNAME=${1:-archlinux-boxv0000}
#export PASSWD_PLAIN=${2:-packer}
export PASSWD_CRYPTED=${2:-\$6\$16CHARACTERSSALT\$A4i3yeafzCxgDj5imBx2ZdMWnr9LGzn3KihP9Dz0zTHbxw31jJGEuuJ6OB6Blkkw0VSUkQzSjE9n4iAAnl0RQ1}

echo "Create /etc/fstab" ; sleep 3
mkdir -p /mnt/etc /mnt/media ; chmod 0755 /mnt/media
#if command -v genfstab > /dev/null ; then
#  genfstab -t LABEL -p /mnt > /mnt/etc/fstab ; # not zfs filesys
#elif command -v fstabgen > /dev/null ; then
#  fstabgen -t LABEL -p /mnt > /mnt/etc/fstab ; # not zfs filesys
#fi
cat << EOF > /mnt/etc/fstab
PARTLABEL=${GRP_NM}-osBoot   /boot       ext2    defaults    0   2
PARTLABEL=ESP      /boot/efi   vfat    umask=0077  0   2
PARTLABEL=${GRP_NM}-osSwap   none        swap    sw          0   0

proc                            /proc       proc    defaults    0   0
sysfs                           /sys        sysfs   defaults    0   0

#9p_Data0           /media/9p_Data0  9p  trans=virtio,version=9p2000.L,rw,_netdev  0  0

#PARTLABEL=data0    /mnt/Data0   exfat   auto,failok,rw,gid=wheel,uid=0   0    0
#PARTLABEL=data0    /mnt/Data0   exfat   auto,failok,rw,dmask=0000,fmask=0111   0    0

EOF

# ip link ; dhcpcd {ifdev} #; iw dev
# networkctl status ; networkctl up {ifdev}
#if [[ ! -z wlan0 ]] ; then      # wlan_ifc: wlan0, wlp2s0
#    wifi-menu wlan0 ;
#fi

#ifdev=$(ip -o link | grep 'link/ether' | grep 'LOWER_UP' | sed -n 's|\S*: \(\w*\):.*|\1|p')


echo "Config pkg repo mirror(s)" ; sleep 3
mkdir -p /mnt/etc/pacman.d /mnt/var/lib/pacman
if [ -f /etc/pacman.conf ] && [ -d /etc/pacman.d ] ; then
  cp /etc/pacman.conf /mnt/etc/pacman.conf ;
  cp /etc/pacman.d/mirrorlist* /mnt/etc/pacman.d/ ;
else
  mkdir -p /etc/pacman.d /mnt/etc/pacman.d /mnt/var/lib/pacman ;
#  cat << EOF > /etc/pacman.conf ;
#[options]
#HoldPkg = pacman glibc
#Architecture = auto
#
#CheckSpace
#SigLevel = Required DatabaseOptional
#LocalFileSigLevel = Optional
#
#[core]
#Include = /etc/pacman.d/mirrorlist
#[extra]
#Include = /etc/pacman.d/mirrorlist
#[community]
#Include = /etc/pacman.d/mirrorlist
#[multilib]
#Include = /etc/pacman.d/mirrorlist
#
#EOF
  if [ "aarch64" = "${UNAME_M}" ] ; then
    #curl -LO http://mirror.archlinuxarm.org/aarch64/core/pacman-6.0.1-3.1-aarch64.pkg.tar.xz ;
    curl -LO https://repo.armtixlinux.org/system/os/aarch64/pacman-6.0.1-3-aarch64.pkg.tar.xz ;
    tar -xf pacman*.pkg.tar.xz etc ;
    cat ./etc/pacman.conf | tee /etc/pacman.conf ;
  else
    curl -s "https://gitea.artixlinux.org/packagesP/pacman/raw/branch/master/trunk/pacman.conf" | tee /etc/pacman.conf ;
  fi ;
  cp /etc/pacman.conf /mnt/etc/pacman.conf ;
fi
## fetch cmd: [curl -s | wget -qO -]
if [ "aarch64" = "${UNAME_M}" ] ; then
  #curl -LO http://mirror.archlinuxarm.org/aarch64/core/pacman-mirrorlist-20220222-1-any.pkg.tar.xz ;
  #tar -xf pacman-mirrorlist*.pkg.tar.xz ;
  #cat ./etc/pacman.d/mirrorlist | tee /etc/pacman.d/mirrorlist-archlinuxarm ;
  curl -LO https://repo.armtixlinux.org/system/os/aarch64/artix-mirrorlist-20220301-1-any.pkg.tar.xz ;
  tar -xf artix-mirrorlist*.pkg.tar.xz ;
  cat ./etc/pacman.d/mirrorlist | tee /etc/pacman.d/mirrorlist-armtix ;

  cp /etc/pacman.d/mirrorlist-armtix /etc/pacman.d/mirrorlist ;
  #cp /etc/pacman.d/mirrorlist-archlinuxarm /etc/pacman.d/mirrorlist-archlinuxarm.bak
  #rankmirrors -vn 10 /etc/pacman.d/mirrorlist-archlinuxarm.bak | tee /etc/pacman.d/mirrorlist-archlinuxarm
else
  #reflector --verbose --country ${LOCALE_COUNTRY:-US} --sort rate --fastest 10 --save /etc/pacman.d/mirrorlist-arch
  curl -s "https://archlinux.org/mirrorlist/?country=${LOCALE_COUNTRY:-US}&use_mirror_status=on" | sed -e 's|^#Server|Server|' -e '/^#/d' | tee /etc/pacman.d/mirrorlist-arch
  curl -s "https://gitea.artixlinux.org/packagesA/artix-mirrorlist/raw/branch/master/trunk/mirrorlist" | tee /etc/pacman.d/mirrorlist-artix

  cp /etc/pacman.d/mirrorlist-artix /etc/pacman.d/mirrorlist
  #cp /etc/pacman.d/mirrorlist-arch /etc/pacman.d/mirrorlist-arch.bak
  #rankmirrors -vn 10 /etc/pacman.d/mirrorlist-arch.bak | tee /etc/pacman.d/mirrorlist-arch
fi

sleep 5 ; cp /mnt/etc/pacman.conf /mnt/etc/pacman.conf.old
cp `ls /etc/pacman.d/mirrorlist*` /mnt/etc/pacman.d/
for libname in multilib lib32 ; do
  MULTILIB_LINENO=$(grep -n "\[$libname\]" /mnt/etc/pacman.conf | cut -f1 -d:) ;
  if [ "" = "${MULTILIB_LINENO}" ] ; then continue ; fi ;
  sed -i "${MULTILIB_LINENO}s|^#||" /mnt/etc/pacman.conf ;
  MULTILIB_LINENO=$(( $MULTILIB_LINENO + 1 )) ;
  sed -i "${MULTILIB_LINENO}s|^#||" /mnt/etc/pacman.conf ;
done


## init [artix | archlinux] pacman keyring
sed -i 's|\(^SigLevel.*\)|#\1\nSigLevel = Never|' /etc/pacman.conf
pacman-key --init ; pacman -Sy --noconfirm artix-keyring
pacman -U --noconfirm `ls /var/cache/pacman/pkg/artix-keyring*`
pacman-key --populate artix
#pacman-key --recv-keys 'arch@eworm.de' ; pacman-key --lsign-key 498E9CEE
#pacman-key --lsign-key 53C01BC2 ; pacman-key --lsign-key F165BBAC
if [ "x86_64" = "${UNAME_M}" ] ; then
  sed -i 's|^#\(SigLevel.*\)|\1| ; s|^\(SigLevel = Never\)|#\1|' /etc/pacman.conf ;
fi
#cat $(dirname $0)/repo_archzfs.cfg | tee -a /mnt/etc/pacman.conf
cat << EOF >> /mnt/etc/pacman.conf
[archzfs]
Server = http://archzfs.com/\$repo/\$arch
Server = http://mirror.sum7.eu/archlinux/archzfs/\$repo/\$arch
Server = https://mirror.biocrafting.net/archlinux/archzfs/\$repo/\$arch
Server = https://mirror.in.themindsmaze.com/archzfs/\$repo/\$arch
Server = https://zxcvfdsa.com/archzfs/\$repo/\$arch

EOF


if [ "aarch64" = "${UNAME_M}" ] ; then
  LINSUF=-aarch64-lts ;
else
  LINSUF=-lts ;
fi

echo "Bootstrap base pkgs" ; sleep 3
zfs umount $ZPOOLNM/var/mail ; zfs destroy $ZPOOLNM/var/mail
pkg_list="base base-devel amd-ucode linux-firmware dosfstools e2fsprogs xfsprogs sysfsutils grub efibootmgr usbutils inetutils logrotate which dialog man-db man-pages less perl s-nail texinfo diffutils vi nano sudo elogind-${service_mgr} mkinitcpio"
# ifplugd # wpa_actiond iw wireless_tools
#pacman -Sg base | cut -d' ' -f2 | sed "s|^linux$|linux${LINSUF}|g" | pacstrap /mnt -
if command -v pacstrap > /dev/null ; then
  pacstrap /mnt --noconfirm $(pacman -Sqg base | sed "s|^linux$|&${LINSUF}|") $pkg_list linux${LINSUF} ;
elif command -v basestrap > /dev/null ; then
  basestrap /mnt --noconfirm $(pacman -Sqg base | sed "s|^linux$|&${LINSUF}|") $pkg_list linux${LINSUF} ;
else
  pacman --root /mnt -Sy --noconfirm $pkg_list linux${LINSUF} ;
fi

echo "Prepare chroot (mount --[r]bind devices)" ; sleep 3
#if command -v arch-chroot > /dev/null ; then
#  CHROOT_CMD=arch-chroot ;
#elif command -v artix-chroot > /dev/null ; then
#  CHROOT_CMD=artix-chroot ;
#elif command -v artools-chroot > /dev/null ; then
#  CHROOT_CMD=artools-chroot ;
#fi
CHROOT_CMD=chroot
#cp /etc/mtab /mnt/etc/mtab
mkdir -p /mnt/dev /mnt/proc /mnt/sys /mnt/run
mount --rbind /proc /mnt/proc ; mount --rbind /sys /mnt/sys
mount --rbind /dev /mnt/dev

mount --rbind /dev/pts /mnt/dev/pts ; mount --rbind /run /mnt/run
modprobe efivarfs
mount -t efivarfs efivarfs /mnt/sys/firmware/efi/efivars/


cp /etc/resolv.conf /mnt/etc/resolv.conf
curl -o /mnt/tmp/archzfs.gpg https://archzfs.com/archzfs.gpg
cp /tmp/init/archlinux/repo_archzfs.cfg /mnt/tmp/
cp /etc/zfs/zpool.cache /mnt/etc/zfs/


cat << EOFchroot | LANG=en_US.UTF-8 LANGUAGE=en $CHROOT_CMD /mnt /bin/sh
set -x

chmod 1777 /tmp ; chmod 1777 /var/tmp

unset LC_ALL
export TERM=xterm-color     # xterm | xterm-color
#hostname ${INIT_HOSTNAME}

ls /proc ; sleep 5 ; ls /dev ; sleep 5

if [ -f /etc/os-release ] ; then
  . /etc/os-release ;
elif [ -f /usr/lib/os-release ] ; then
  . /usr/lib/os-release ;
fi
cat /etc/pacman.conf ; sleep 5

sed -i 's|\(^SigLevel.*\)|#\1\nSigLevel = Never|' /etc/pacman.conf
pacman-key --init
if [ "arch" = "\${ID}" ] || [ "archarm" = "\${ID}" ] ; then
  pacman --needed -Sy --noconfirm archlinux-keyring ;
  pacman -U --noconfirm \$(ls /var/cache/pacman/pkg/archlinux-keyring*) ;
  pacman-key --populate archlinux ;
elif [ "artix" = "\${ID}" ] || [ "armtix" = "\${ID}" ] ; then
  pacman --needed -Sy --noconfirm artix-keyring ;
  pacman -U --noconfirm \$(ls /var/cache/pacman/pkg/artix-keyring*) ;
  pacman-key --populate artix ;
fi
#pacman-key --recv-keys 'arch@eworm.de' ; pacman-key --lsign-key 498E9CEE
#pacman-key --lsign-key 53C01BC2 ; pacman-key --lsign-key F165BBAC
if [ "x86_64" = "${UNAME_M}" ] ; then
  sed -i 's|^#\(SigLevel.*\)|\1| ; s|^\(SigLevel = Never\)|#\1|' /etc/pacman.conf
fi
pacman --noconfirm --needed -S linux${LINSUF} ; pacman --noconfirm -S linux${LINSUF}-headers
if [ "arch" = "\${ID}" ] || [ "archarm" = "\${ID}" ] ; then
  pacman --noconfirm --needed -S cryptsetup device-mapper mdadm dhcpcd openssh ;
elif [ "artix" = "\${ID}" ] || [ "armtix" = "\${ID}" ] ; then
  if command -v rc-update > /dev/null ; then
    service_mgr=openrc ;
  elif command -v sv > /dev/null ; then
    service_mgr=runit ;
  elif command -v s6-rc > /dev/null ; then
    service_mgr=s6 ;
  fi ;
  pacman --noconfirm --needed -S cryptsetup-\${service_mgr} device-mapper-\${service_mgr} mdadm-\${service_mgr} dhcpcd-\${service_mgr} openssh-\${service_mgr} ;
fi
#pacman --noconfirm --needed -S xfce4


curl -o /tmp/archzfs.gpg https://archzfs.com/archzfs.gpg
#cat /tmp/repo_archzfs.cfg >> /etc/pacman.conf
pacman-key --add /tmp/archzfs.gpg ; pacman-key --lsign-key F75D9D76
pacman -Syu

pacman --noconfirm -Sy --needed linux${LINSUF}-headers zfs-dkms # archzfs-linux-lts
pacman --noconfirm -Sy --needed zfs-utils
echo REMAKE_INITRD=yes > /etc/dkms/zfs.conf
sh -c 'cat >> /etc/modules-load.d/zfs.conf' << EOF
# load zfs.ko at boot
zfs

EOF
modprobe zfs ; zfs version ; sleep 5
#pacman --noconfirm -Sy zfs-linux-lts zfs-utils
pacman --noconfirm -Sy linux${LINSUF}

echo "Config keyboard ; localization" ; sleep 3
kbd_mode -u ; loadkeys us
sed -i -e '/en_US.UTF-8 UTF-8/ s|^# ||' /etc/locale.gen
echo 'LANG=en_US.UTF-8' > /etc/locale.conf
locale-gen


echo "Config time zone & clock" ; sleep 3
ln -sf /usr/share/zoneinfo/UTC /etc/localtime
hwclock --systohc --utc


echo "Config hostname ; network" ; sleep 3
echo "${INIT_HOSTNAME}" > /etc/hostname
resolvconf -u   # generates /etc/resolv.conf
cat /etc/resolv.conf ; sleep 5
sed -i '/127.0.1.1/d' /etc/hosts
echo "127.0.1.1		${INIT_HOSTNAME}.localdomain	${INIT_HOSTNAME}" >> /etc/hosts

ifdev=\$(ip -o link | grep 'link/ether' | grep 'LOWER_UP' | sed -n 's|\S*: \(\w*\):.*|\1|p')
#mkdir -p /etc/systemd/network
#sh -c 'cat > /etc/systemd/network/80-wired-dhcp.network' << EOF
#[Match]
#Name=en*
#
#[Network]
#DHCP=yes
#EOF


echo "Update services" ; sleep 3
if command -v systemctl > /dev/null ; then
  ## IP address config options: systemd-networkd, dhcpcd, dhclient, netctl
  #systemctl enable systemd-networkd.service ;

  systemctl enable dhcpcd@\${ifdev}.service ; # dhcpcd.service

  #systemctl enable dhclient@\${ifdev}.service ;
  #systemctl start dhclient@\${ifdev}.service ;

  #cp /etc/netctl/examples/ethernet-dhcp /etc/netctl/basic_dhcp_profile ;
  #systemctl enable netctl-ifplugd@\${ifdev}.service # netctl-auto@\${ifdev}.service ;

  systemctl enable sshd.service #; systemctl enable sshd.socket ;

  systemctl enable zfs-import-cache ; systemctl enable zfs-import.target ;
  systemctl enable zfs-mount ; systemctl enable zfs.target ;
elif command -v s6-rc > /dev/null ; then
  ## IP address config options: dhcpcd, dhclient
  s6-rc-bundle-update add default dhcpcd ;
  s6-rc-bundle -c /etc/s6/rc/compiled add default dhcpcd ;

  #s6-rc-bundle-update add default dhclient ;
  s6-rc-bundle -c /etc/s6/rc/compiled add default dhclient ;
  #s6-rc -u change dhclient ;

  s6-rc-bundle-update add default sshd ;
  s6-rc-bundle -c /etc/s6/rc/compiled add default sshd ;
elif command -v sv > /dev/null ; then
  ## IP address config options: dhcpcd, dhclient
  ln -s /etc/runit/sv/dhcpcd /etc/runit/runsvdir/default/ ;

  #ln -s /etc/runit/sv/dhclient /etc/runit/runsvdir/default/ ;
  #sv up dhclient ;

  ln -s /etc/runit/sv/sshd /etc/runit/runsvdir/default/ ;

  mkdir -p /etc/runit/sv/zfs-mount/supervise ;
  cat << EOF >> /etc/runit/sv/zfs-mount/run ;
#!/bin/sh

zfs mount $ZPOOLNM/ROOT/default ; zfs mount -a

EOF

  chmod +x /etc/runit/sv/zfs-mount/run ;
  ln -s /etc/runit/sv/zfs-mount /etc/runit/runsvdir/default/ ;
elif command -v rc-update > /dev/null ; then
  ## IP address config options: dhcpcd, dhclient
  rc-update add dhcpcd default ;

  #rc-update add dhclient default ;
  #rc-service dhclient start ;

  rc-update add sshd default ;

  mkdir -p /etc/init.d ;
  cat << EOF >> /etc/init.d/zfs-mount ;
#!/sbin/openrc-run

command="zfs mount $ZPOOLNM/ROOT/default ; zfs mount -a"

EOF

  chmod +x /etc/init.d/zfs-mount ;
  rc-update add zfs-mount boot ;
fi


echo "Set root passwd ; add user" ; sleep 3
#echo -n "root:${PASSWD_PLAIN}" | chpasswd
echo -n 'root:${PASSWD_CRYPTED}' | chpasswd -e

#DIR_MODE=0750
useradd -g users -m -G wheel -s /bin/bash -c 'Packer User' packer
#echo -n "packer:${PASSWD_PLAIN}" | chpasswd
echo -n 'packer:${PASSWD_CRYPTED}' | chpasswd -e
chown -R packer:\$(id -gn packer) /home/packer

#sh -c 'cat > /etc/sudoers.d/99_packer' << EOF
#Defaults:packer !requiretty
#\$(id -un packer) ALL=(ALL) NOPASSWD: ALL
#
#EOF
#chmod 0440 /etc/sudoers.d/99_packer


sed -i "/^%wheel.*(ALL)\s*ALL/ s|%wheel|# %wheel|" /etc/sudoers
sed -i "/^#.*%wheel.*NOPASSWD.*/ s|^#.*%wheel|%wheel|" /etc/sudoers
sed -i "s|^[^#].*requiretty|# Defaults requiretty|" /etc/sudoers


grub-probe /boot

echo "Customize initial ramdisk (hooks: zfs)" ; sleep 3
sed -i '/^HOOK/ s| keyboard||' /etc/mkinitcpio.conf
#sed -i '/^HOOK/ s|filesystems|encrypt zfs usr filesystems|' /etc/mkinitcpio.conf	# encrypt hook only if crypted root partition
sed -i '/^HOOK/ s|filesystems|keyboard zfs usr filesystems|' /etc/mkinitcpio.conf
mkinitcpio -p linux${LINSUF} #; mkinitcpio -P

echo "Hold zfs & kernel package upgrades (require manual upgrade)"
sed -i 's|#IgnorePkg|IgnorePkg|' /etc/pacman.conf
for pkgX in zfs-dkms zfs-utils linux${LINSUF} linux${LINSUF}-headers ; do
  sed -i "/^IgnorePkg/ s|\$| \${pkgX}|" /etc/pacman.conf
done
grep -e '^IgnorePkg' /etc/pacman.conf ; sleep 3


echo "Bootloader installation & config" ; sleep 3
mkdir -p /boot/efi/EFI/\${ID} /boot/efi/EFI/BOOT
if [ "aarch64" = "${UNAME_M}" ] ; then
  grub-install --target=arm64-efi --efi-directory=/boot/efi --bootloader-id=\${ID} --recheck --removable ;
  cp /boot/efi/EFI/\${ID}/grubaa64.efi /boot/efi/EFI/BOOT/BOOTAA64.EFI ;
else
  grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=\${ID} --recheck --removable ;
  grub-install --target=i386-pc --recheck /dev/$DEVX ;
  cp /boot/efi/EFI/\${ID}/grubx64.efi /boot/efi/EFI/BOOT/BOOTX64.EFI ;
fi

#sed -i -e "s|^GRUB_TIMEOUT=.*$|GRUB_TIMEOUT=1|" /etc/default/grub
#sed -i -e "/GRUB_DEFAULT/ s|=.*$|=saved|" /etc/default/grub
#echo "GRUB_SAVEDEFAULT=true" >> /etc/default/grub
sed -i -e '/GRUB_CMDLINE_LINUX_DEFAULT/ s|="\(.*\)"|="\1 text xdriver=vesa nomodeset zfs=${ZPOOLNM}/ROOT/default resume=/dev/foo rootdelay=10"|' /etc/default/grub
#sed -i -e '/GRUB_CMDLINE_LINUX_DEFAULT/ s|="\(.*\)"|="\1 video=1024x768 "|' /etc/default/grub
echo 'GRUB_PRELOAD_MODULES="zfs"' >> /etc/default/grub
if [ "\$(dmesg | grep -ie 'Hypervisor detected')" ] ; then
  sed -i -e '/GRUB_CMDLINE_LINUX_DEFAULT/ s|="\(.*\)"|="\1 net.ifnames=0 biosdevname=0"|' /etc/default/grub ;
fi
if [ "aarch64" = "${UNAME_M}" ] ; then
  sed -i -e "/GRUB_DEFAULT/ s|=.*$|=1|" /etc/default/grub ;
  cat << EOF >> /etc/grub.d/40_custom ;
    menuentry "(aarch64) Arch Linux variant" {
        terminal_output gfxterm

        search --no-floppy --label vg0-osBoot
        #set root=hd0,gpt3
        #echo $root ; sleep 5

        linux /ltsImage root=LABEL=vg0-osRoot
        initrd /initramfs-linux-lts.img
    }
EOF

fi
grub-mkconfig -o /boot/grub/grub.cfg

if [ "aarch64" = "${UNAME_M}" ] ; then
  efibootmgr -c -d /dev/$DEVX -p \$(lsblk -nlpo name,label,partlabel | sed -n '/ESP/ s|.*[sv]da\([0-9]*\).*|\1|p') -l "/EFI/\${ID}/grubaa64.efi" -L \${ID}
  efibootmgr -c -d /dev/$DEVX -p \$(lsblk -nlpo name,label,partlabel | sed -n '/ESP/ s|.*[sv]da\([0-9]*\).*|\1|p') -l "/EFI/BOOT/BOOTAA64.EFI" -L Default
else
  efibootmgr -c -d /dev/$DEVX -p \$(lsblk -nlpo name,label,partlabel | sed -n '/ESP/ s|.*[sv]da\([0-9]*\).*|\1|p') -l "/EFI/\${ID}/grubx64.efi" -L \${ID}
  efibootmgr -c -d /dev/$DEVX -p \$(lsblk -nlpo name,label,partlabel | sed -n '/ESP/ s|.*[sv]da\([0-9]*\).*|\1|p') -l "/EFI/BOOT/BOOTX64.EFI" -L Default
fi
efibootmgr -v ; sleep 3


pacman --noconfirm -Sc
zpool trim ${ZPOOLNM} ; zpool set autotrim=on ${ZPOOLNM}
sync

exit

EOFchroot
# end chroot commands

tar -xf /tmp/scripts.tar -C /mnt/root/ ; sleep 5

read -p "Enter 'y' if ready to unmount & reboot [yN]: " response
if [ "y" = "$response" ] || [ "Y" = "$response" ] ; then
  sync ; swapoff -va ; umount -vR /mnt ; zfs umount -a ; zpool export -a ;
  reboot ; #poweroff ;
fi
