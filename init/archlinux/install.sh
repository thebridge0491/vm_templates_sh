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
export UNAME_M=$(uname -m)
export service_mgr=${service_mgr:-runit} # openrc | runit | s6


# ip link ; dhcpcd {ifdev} #; iw dev
# [networkctl status ; networkctl up {ifdev}]
#if [[ ! -z wlan0 ]] ; then      # wlan_ifc: wlan0, wlp2s0
#  wifi-menu wlan0 ;
#fi

#ntpd -u ntp:ntp ; ntpq -p ; ntpctl -s peers ; sleep 3

#ifdev=$(ip -o link | grep 'link/ether' | grep 'LOWER_UP' | sed -n 's|\S*: \(\w*\):.*|\1|p')


export CHROOT_CMD=chroot
#if command -v arch-chroot > /dev/null ; then
#  export CHROOT_CMD=arch-chroot ; # (archlinux: pkg arch-install-scripts)
#elif command -v artix-chroot > /dev/null ; then
#  export CHROOT_CMD=artix-chroot ; # (artix: pkg artools-base)
#elif command -v xchroot > /dev/null ; then
#  export CHROOT_CMD=xchroot ; # (void: pkg xtools[-minimal])
#fi

_rootfs_extract() {
  #curl -Lo /tmp/rootfs.tar.zst \
    #http://mirror.math.princeton.edu/pub/archlinux/iso/2024.03.01/archlinux-bootstrap-${UNAME_M}.tar.zst
  #curl -Lo /tmp/CHECKSUM \
  #  http://mirror.math.princeton.edu/pub/archlinux/iso/2024.03.01/sha256sums.txt
  #ln -s /tmp/rootfs.tar.zst /tmp/archlinux-bootstrap-${UNAME_M}.tar.zst
  #sha256sum --ignore-missing -c /tmp/CHECKSUM
  ##(cat /tmp/rootfs.tar.zst | tar --unlink --zstd -xpf - -C ${DESTDIR:-/mnt})
  #(cat /tmp/rootfs.tar.zst | tar --zstd -xaf - -C ${DESTDIR:-/mnt})
  #sed -i '/DownloadUser = alpm/ s|^|#|' /mnt/etc/pacman.conf
  curl -Lo /tmp/artix-bootstrap.tar.gz \
    http://gitea.artixlinux.org/artix/artix-bootstrap/archive/master.tar.gz
  tar -xf /tmp/artix-bootstrap.tar.gz -C /tmp

  sed -i '/CheckSpace.*\/etc\/pacman.conf"/i\  sed -i "/DownloadUser = alpm/ s|^|#|" "\$DEST/etc/pacman.conf"' \
    /tmp/artix-bootstrap/artix-bootstrap.sh
  bash /tmp/artix-bootstrap/artix-bootstrap.sh -i ${service_mgr} /mnt
}

_config_repo_mirrors() {
  echo "Config pkg repo mirror(s)" ; sleep 3
  mkdir -p /mnt/etc/pacman.d /mnt/var/lib/pacman
  if [ -f /etc/pacman.conf ] && [ -d /etc/pacman.d ] ; then
    cp -a /etc/pacman.conf /mnt/etc/pacman.conf ;
    cp -a /etc/pacman.d/mirrorlist* /mnt/etc/pacman.d/ ;
  else
    mkdir -p /etc/pacman.d /mnt/etc/pacman.d /mnt/var/lib/pacman ;
    cat << EOF > /etc/pacman.conf.try ;
[options]
HoldPkg = pacman glibc
Architecture = auto

#CheckSpace
SigLevel = Required DatabaseOptional
#SigLevel = Never
LocalFileSigLevel = Optional

# (archlinux: core ; artix: system)
[system]
Include = /etc/pacman.d/mirrorlist
# (archlinux: extra ; artix: world)
[world]
Include = /etc/pacman.d/mirrorlist
# (archlinux: community ; artix: galaxy)
[galaxy]
Include = /etc/pacman.d/mirrorlist
# (archlinux: multilib ; artix: lib32)
[lib32]
Include = /etc/pacman.d/mirrorlist

EOF
    if [ "aarch64" = "${UNAME_M}" ] ; then
      #pacmanconf_ver=$(curl -Ls http://mirror.archlinuxarm.org/aarch64/core | sed -n 's|.*pacman-\(.*\)-aarch64.pkg.tar.xz.*|\1|p') ;
      #curl -LO http://mirror.archlinuxarm.org/aarch64/core/pacman-${pacmanconf_ver:-6.1.0-3}-aarch64.pkg.tar.xz ;
      pacmanconf_ver=$(curl -Ls https://repo.armtixlinux.org/system/os/aarch64 | sed -n 's|.*pacman-\(.*\)-aarch64.pkg.tar.xz.*|\1|p') ;
      curl -LO https://repo.armtixlinux.org/system/os/aarch64/pacman-${pacmanconf_ver:-6.1.0-3}-aarch64.pkg.tar.xz ;
      tar -xf pacman*.pkg.tar.xz etc ;
      cat ./etc/pacman.conf | tee /etc/pacman.conf ;
    else
      #curl -s "https://gitea.artixlinux.org/packagesP/pacman/raw/branch/master/trunk/pacman.conf" | tee /etc/pacman.conf ;
      curl -s "https://gitea.artixlinux.org/packages/pacman/raw/branch/master/pacman.conf" | tee /etc/pacman.conf ;
    fi ;
    cp -a /etc/pacman.conf /etc/pacman.conf.try /mnt/etc/ ;
  fi
  ## fetch cmd: [curl -s | wget -qO -]
  if [ "aarch64" = "${UNAME_M}" ] ; then
    #mirrorlist_ver=$(curl -Ls http://mirror.archlinuxarm.org/aarch64/core | sed -n 's|.*pacman-mirrorlist-\(.*\)-any.pkg.tar.xz.*|\1|p') ;
    #curl -LO http://mirror.archlinuxarm.org/aarch64/core/pacman-mirrorlist-${mirrorlist_ver:-20230206-1}-any.pkg.tar.xz ;
    #tar -xf pacman-mirrorlist*.pkg.tar.xz ;
    #cat ./etc/pacman.d/mirrorlist | tee /etc/pacman.d/mirrorlist-archlinuxarm ;
    mirrorlist_ver=$(curl -Ls https://repo.armtixlinux.org/system/os/aarch64 | sed -n 's|.*artix-mirrorlist-\(.*\)-any.pkg.tar.xz.*|\1|p') ;
    curl -LO https://repo.armtixlinux.org/system/os/aarch64/artix-mirrorlist-${mirrorlist_ver:-20230501-1}-any.pkg.tar.xz ;
    tar -xf artix-mirrorlist*.pkg.tar.xz ;
    cat ./etc/pacman.d/mirrorlist | tee /etc/pacman.d/mirrorlist-armtix ;

    cp -a /etc/pacman.d/mirrorlist-armtix /etc/pacman.d/mirrorlist ;
    #cp -a /etc/pacman.d/mirrorlist-archlinuxarm /etc/pacman.d/mirrorlist-archlinuxarm.bak
    #rankmirrors -vn 10 /etc/pacman.d/mirrorlist-archlinuxarm.bak | tee /etc/pacman.d/mirrorlist-archlinuxarm
  else
    #reflector --verbose --country ${LOCALE_COUNTRY:-US} --sort rate --fastest 10 --save /etc/pacman.d/mirrorlist-arch
    curl -s "https://archlinux.org/mirrorlist/?country=${LOCALE_COUNTRY:-US}&use_mirror_status=on" | sed -e 's|^#Server|Server|' -e '/^#/d' | tee /etc/pacman.d/mirrorlist-arch
    #curl -s "https://gitea.artixlinux.org/packagesA/artix-mirrorlist/raw/branch/master/trunk/mirrorlist" | tee /etc/pacman.d/mirrorlist-artix
    curl -s "https://gitea.artixlinux.org/packages/artix-mirrorlist/raw/branch/master/mirrorlist" | tee /etc/pacman.d/mirrorlist-artix

    cp -a /etc/pacman.d/mirrorlist-artix /etc/pacman.d/mirrorlist
    #cp -a /etc/pacman.d/mirrorlist-arch /etc/pacman.d/mirrorlist-arch.bak
    #rankmirrors -vn 10 /etc/pacman.d/mirrorlist-arch.bak | tee /etc/pacman.d/mirrorlist-arch
  fi

  sleep 5 ; cp -a /mnt/etc/pacman.conf /mnt/etc/pacman.conf.old
  cp -a `ls /etc/pacman.d/mirrorlist*` /mnt/etc/pacman.d/
  for libname in multilib lib32 ; do
    MULTILIB_LINENO=$(grep -n "\[${libname}\]" /mnt/etc/pacman.conf | cut -f1 -d:) ;
    if [ "" = "${MULTILIB_LINENO}" ] ; then continue ; fi ;
    sed -i "${MULTILIB_LINENO}s|^#||" /mnt/etc/pacman.conf ;
    MULTILIB_LINENO=$(( ${MULTILIB_LINENO} + 1 )) ;
    sed -i "${MULTILIB_LINENO}s|^#||" /mnt/etc/pacman.conf ;
  done
}

bootstrap() {
  echo "Bootstrap base pkgs" ; sleep 3
  if [ "zfs" = "${VOL_MGR}" ] ; then
    zfs umount ${ZPOOLNM}/var/mail ; zfs destroy ${ZPOOLNM}/var/mail ;
  fi
  pkg_list="base base-devel lsb-release dosfstools e2fsprogs xfsprogs inetutils logrotate dialog man-db man-pages less diffutils vi nano whois elogind-${service_mgr}"
  # reiserfsprogs jfsutils sysfsutils usbutils perl s-nail texinfo # iw wireless_tools ifplugd wpa_actiond
  if command -v pacstrap > /dev/null || command -v basestrap > /dev/null || command -v pacman > /dev/null ; then
    _config_repo_mirrors ;

    sed -i '/DownloadUser = alpm/ s|^|#|' /etc/pacman.conf
    ## init [artix | archlinux] pacman keyring
    sed -i 's|\(^SigLevel.*\)|#\1\nSigLevel = Never|' /etc/pacman.conf
    pacman-key --init ; pacman-key --populate artix
    pacman -Sy --noconfirm artix-keyring
    pacman -U --noconfirm `ls /var/cache/pacman/pkg/artix-keyring*`
    pacman-key --recv-keys 'arch@eworm.de' ; pacman-key --lsign-key 498E9CEE
    pacman-key --lsign-key 53C01BC2 ; pacman-key --lsign-key F165BBAC
    if [ "x86_64" = "${UNAME_M}" ] ; then
      sed -i 's|^#\(SigLevel.*\)|\1| ; s|^\(SigLevel = Never\)|#\1|' /etc/pacman.conf ;
    fi

    ##pacman -Sg base | cut -d' ' -f2 | sed "s|^linux$|linux-lts|g" | pacstrap /mnt -
    #pacman -Sg base | cut -d' ' -f2 | sed "s|^linux$||g" | pacstrap /mnt -
    if command -v pacstrap > /dev/null ; then
      #pacstrap /mnt --noconfirm $(pacman -Sqg base | sed "s|^linux$|&${SUF}|g") ${pkg_list} ;
      pacstrap /mnt --noconfirm $(pacman -Sqg base | sed "s|^linux$||g") ${pkg_list} ;
    elif command -v basestrap > /dev/null ; then
      basestrap /mnt --noconfirm $(pacman -Sqg base | sed "s|^linux$||g") ${pkg_list} ;
    elif command -v pacman > /dev/null ; then
      pacman --root /mnt -Sy --noconfirm $(pacman -Sqg base | sed "s|^linux$||g") ${pkg_list} ;
    fi
  else
    mv /mnt/etc/fstab /mnt/etc/fstab.disk_setup ;
    _rootfs_extract ;
    cp -a /mnt/etc/fstab /mnt/etc/fstab.rootfs ;
    cp -a /mnt/etc/fstab.disk_setup /mnt/etc/fstab ;
    mv /mnt/etc/resolv.conf /mnt/etc/resolv.conf.rootfs ;
    cp /etc/resolv.conf /mnt/etc/resolv.conf ; #cp /etc/mtab /mnt/etc/mtab ;
    # LANG=[C|en_US].UTF-8
    cat << EOFchroot | LANG=C.UTF-8 LANGUAGE=en ${CHROOT_CMD} /mnt /bin/sh ;
set -x

unalias -a

pacman -Sy --needed --noconfirm \$(pacman -Sqg base | sed "s|^linux$||g") ${pkg_list}

exit

EOFchroot
  fi
  sleep 5

  #cp /etc/mtab /mnt/etc/mtab
  mkdir -p /mnt/proc /mnt/sys /mnt/dev /mnt/run
  if [ "chroot" = "${CHROOT_CMD}" ] ; then
    echo "Prepare chroot (mount --[r]bind devices)" ; sleep 3
    cp /etc/resolv.conf /mnt/etc/resolv.conf

    #mount --rbind /proc /mnt/proc ; mount --rbind /sys /mnt/sys
    #mount --rbind /dev /mnt/dev ; mount --rbind /dev/pts /mnt/dev/pts
    #mount --rbind /run /mnt/run ; mount --rbind /dev/shm /mnt/dev/shm
    for fsX in /proc /sys /dev /dev/pts /run /dev/shm ; do
      mount --rbind ${fsX} /mnt${fsX} ;
    done
  fi
  modprobe efivarfs
  mount -t efivarfs efivarfs /mnt/sys/firmware/efi/efivars/
  sleep 5
}

system_config() {
  export INIT_HOSTNAME=${1:-archlinux-boxv0000}
  #export PASSWD_PLAIN=${2:-packer}
  export PASSWD_CRYPTED=${2:-\$6\$16CHARACTERSSALT\$A4i3yeafzCxgDj5imBx2ZdMWnr9LGzn3KihP9Dz0zTHbxw31jJGEuuJ6OB6Blkkw0VSUkQzSjE9n4iAAnl0RQ1}

  # LANG=[C|en_US].UTF-8
  cat << EOFchroot | LANG=C.UTF-8 LANGUAGE=en ${CHROOT_CMD} /mnt /bin/sh
set -x

chmod 1777 /tmp ; chmod 1777 /var/tmp

unset LC_ALL
export TERM=xterm-color     # xterm | xterm-color
#hostname ${INIT_HOSTNAME}

ls /proc ; sleep 5 ; ls /dev ; sleep 5

. /etc/os-release
if [ ! -e /etc/os-release ] && [ -f /usr/lib/os-release ] ; then
  . /usr/lib/os-release ;
fi
cat /etc/pacman.conf ; sleep 5

sed -i 's|\(^SigLevel.*\)|#\1\nSigLevel = Never|' /etc/pacman.conf
pacman-key --init
if [ "arch" = "\${ID}" ] || [ "archarm" = "\${ID}" ] ; then
  pacman-key --populate archlinux ;
  pacman -Sy --needed --noconfirm archlinux-keyring ;
  pacman -U --noconfirm \$(ls /var/cache/pacman/pkg/archlinux-keyring*) ;
elif [ "artix" = "\${ID}" ] || [ "armtix" = "\${ID}" ] ; then
  pacman-key --populate artix ;
  pacman -Sy --needed --noconfirm artix-keyring ;
  pacman -U --noconfirm \$(ls /var/cache/pacman/pkg/artix-keyring*) ;
fi
#pacman-key --recv-keys 'arch@eworm.de' ; pacman-key --lsign-key 498E9CEE
#pacman-key --lsign-key 53C01BC2 ; pacman-key --lsign-key F165BBAC
if [ "x86_64" = "${UNAME_M}" ] ; then
  sed -i 's|^#\(SigLevel.*\)|\1| ; s|^\(SigLevel = Never\)|#\1|' /etc/pacman.conf
fi

pkg_list="base base-devel whois"
services_enabled="dhcpcd sshd logind"
if [ "arch" = "\${ID}" ] || [ "archarm" = "\${ID}" ] ; then
  pkg_list="\${pkg_list} dhcpcd openssh python python-urllib3" ; # xfce4

elif [ "artix" = "\${ID}" ] || [ "armtix" = "\${ID}" ] ; then
  if command -v s6-rc > /dev/null ; then
    service_mgr=s6 ;
  elif command -v sv > /dev/null ; then
    service_mgr=runit ;
  elif command -v rc-update > /dev/null ; then
    service_mgr=openrc ;
  fi ;
  pkg_list="\${pkg_list} dhcpcd-\${service_mgr} openssh-\${service_mgr} python python-urllib3" ; # xfce4
fi
for pkgX in \${pkg_list} ; do
  pacman -S --needed --noconfirm \${pkgX} ;
done

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
sed -i '/^127.0.1.1/ s|127.0.1.1|#127.0.1.1|' /etc/hosts
echo "127.0.1.1   ${INIT_HOSTNAME}.localdomain  ${INIT_HOSTNAME}" >> /etc/hosts

ifdev=\$(ip -o link | grep 'link/ether' | grep 'LOWER_UP' | sed -n 's|\S*: \(\w*\):.*|\1|p')

#mkdir -p /etc/systemd/network
#sh -c 'cat > /etc/systemd/network/80-wired-dhcp.network' << EOF
#[Match]
#Name=en*
#
#[Network]
#DHCP=yes
#EOF

echo "Config services" ; sleep 3

## IP address config options: dhcpcd, dhclient,
##   (systemd-only) systemd-networkd, (systemd-only) netctl
if command -v systemctl > /dev/null ; then # service_mgr=systemd
  ## dhcpcd[@\${ifdev:-eth0}], netctl-[ifplugd | auto]@\${ifdev:-eth0}
  #cp -a /etc/netctl/examples/ethernet-dhcp /etc/netctl/basic_dhcp_profile ;
  cp -a /usr/share/systemd/tmp.mount /etc/systemd/system/ ;
  systemctl enable tmp.mount ; #systemctl enable systemd-machine-id-commit ;
  systemctl stop sshd ;
elif command -v s6-rc > /dev/null ; then # service_mgr=s6
  s6-rc -d change sshd ;
elif command -v sv > /dev/null ; then # service_mgr=runit
  sv down sshd ;

  echo "for runit service ops w/ Ansible,Saltstack" ; sleep 3
  ln -s /etc/runit/sv /etc/sv ;
  ln -s /etc/runit/runsvdir/default /var/service ;
  #ln -s /run/runit/service /var/service ;
elif command -v rc-update > /dev/null ; then # service_mgr=openrc
  rc-service sshd stop ;
fi
#echo "tmpfs                           /tmp        tmpfs   defaults,nosuid,nodev,mode=1777   0   0" >> /etc/fstab

echo "Enable services" ; sleep 3
for svc in \${services_enabled} ; do
  if command -v systemctl > /dev/null ; then
    systemctl enable \${svc} ;
  elif command -v s6-rc > /dev/null ; then
    s6-rc-bundle-update add default \${svc} ;
    s6-rc-bundle -c /etc/s6/rc/compiled add default \${svc} ;
  elif command -v sv > /dev/null ; then
    ln -s /etc/runit/sv/\${svc} /etc/runit/runsvdir/default/ ;
  elif command -v rc-update > /dev/null ; then
    rc-update add \${svc} default ;
  fi ;
done


echo "Set root passwd ; add user" ; sleep 3
#echo -n "root:${PASSWD_PLAIN}" | chpasswd
echo -n 'root:${PASSWD_CRYPTED}' | chpasswd -e

#DIR_MODE=0750
useradd -g users -m -G wheel -s /bin/bash -c 'Packer User' packer
#echo -n "packer:${PASSWD_PLAIN}" | chpasswd
echo -n 'packer:${PASSWD_CRYPTED}' | chpasswd -e
mkdir -m 0700 -p /home/packer/.ssh ; chown -R packer /home/packer

#sh -c 'cat | EDITOR="tee -a" visudo -f /etc/sudoers.d/99_packernopasswd' << EOF
#Defaults:packer !requiretty
#packer ALL=(ALL:ALL) NOPASSWD: ALL
#
#EOF
##chmod 0440 /etc/sudoers.d/99_packernopasswd


#sed -i "/^[^#].*requiretty/ s|^|#|" /etc/sudoers
cat << EOF | EDITOR="tee -a" visudo -f /etc/sudoers.d/99_wheelnopasswd
#Defaults:%wheel !requiretty
%wheel ALL=(ALL:ALL) NOPASSWD: ALL

EOF

pacman -Sc --noconfirm

exit

EOFchroot
# end chroot commands
}

kernel_bootloader() {
  if [ "zfs" = "${VOL_MGR}" ] ; then
    if [ -f "$(dirname ${0})/repo_archzfs.cfg" ] ; then
      cat $(dirname ${0})/repo_archzfs.cfg | tee /mnt/tmp/repo_archzfs.cfg ;
    else
      cat << EOF | tee /mnt/tmp/repo_archzfs.cfg ;
[archzfs]
# Origin Server - Finland
Server = http://archzfs.com/\$repo/\$arch
# Mirror - Germany
Server = http://mirror.sum7.eu/archlinux/archzfs/\$repo/\$arch
# Mirror - Germany
Server = http://mirror.sunred.org/archzfs/\$repo/\$arch
# Mirror - Germany
Server = https://mirror.biocrafting.net/archlinux/archzfs/\$repo/\$arch
# Mirror - India
Server = https://mirror.in.themindsmaze.com/archzfs/\$repo/\$arch
# Mirror - US
Server = https://zxcvfdsa.com/archzfs/\$repo/\$arch

EOF
    fi ;
  fi

  # LANG=[C|en_US].UTF-8
  cat << EOFchroot | LANG=C.UTF-8 LANGUAGE=en ${CHROOT_CMD} /mnt /bin/sh
set -x

. /etc/os-release
if [ ! -e /etc/os-release ] && [ -f /usr/lib/os-release ] ; then
  . /usr/lib/os-release ;
fi

if [ "aarch64" = "${UNAME_M}" ] ; then
  LINSUF=-aarch64-lts ;
else
  LINSUF=-lts ; # older kernel for ZFS compatibility
fi

services_enabled=""
pkg_list="linux\${LINSUF} mkinitcpio amd-ucode grub efibootmgr"

pacman -Sy --needed --noconfirm \${pkg_list}
for pkgX in \${pkg_list} ; do
  pacman -Sy --needed --noconfirm \${pkgX} ;
done

echo "Customize initial ramdisk (hooks: ??)" ; sleep 3
sed -ie '/^HOOKS/ s|^\(.*\)$|#\1\n\1|' /etc/mkinitcpio.conf
#sed -i '/^HOOKS/ s|filesystems|encrypt filesystems|' /etc/mkinitcpio.conf # encrypt hook only if crypted root partition

if [ ! "\$(dmesg | grep -ie 'Hypervisor detected')" ] ; then
  pacman -Sy --needed --noconfirm linux-firmware ;
fi

kver="\$(ls -A /usr/lib/modules/ | tail -1)" # ?? or uname -r
echo \${kver} ; sleep 5

modprobe vfat ; lsmod | grep -e fat ; sleep 5

if [ "zfs" = "${VOL_MGR}" ] ; then
  curl -Lo /tmp/archzfs.gpg https://archzfs.com/archzfs.gpg ;
  if [ ! "\$(grep archzfs /etc/pacman.conf)" ] ; then
    cat /tmp/repo_archzfs.cfg | tee -a /etc/pacman.conf ;
  fi ;
  pacman-key --add /tmp/archzfs.gpg ; pacman-key --lsign-key F75D9D76 ;
  pacman -Syu ;

  zfs_ver=\$(curl -Ls https://zxcvfdsa.com/archzfs/archzfs/x86_64 | sed -n 's|.*zfs-dkms-\([0-9.]*\).*.pkg.tar.zst.*|\1|p' | head -n1)
  pacman -Sy --needed --noconfirm dkms linux\${LINSUF}-headers \
    zfs-dkms=\${zfs_ver:-2.2.4} zfs-utils=\${zfs_ver:-2.2.4} ;
  pacman -Sy --needed --noconfirm dkms linux\${LINSUF}-headers \
    zfs-dkms=\${zfs_ver:-2.2.4} zfs-utils=\${zfs_ver:-2.2.4} ;
  # archzfs-linux-lts
  echo REMAKE_INITRD=yes > /etc/dkms/zfs.conf ;
  sh -c 'cat >> /etc/modules-load.d/zfs.conf' << EOF ;
# load zfs.ko at boot
zfs

EOF
  zfs_ver=\$(zfs version | head -n1 | sed 's|zfs-||') ;
  dkms install --verbose zfs/\${zfs_ver} -k \${kver}.${UNAME_M} ;
  dkms status ; modprobe zfs ; zfs version ; sleep 5 ;

  zgenhostid -f -o /etc/hostid ; sleep 5 ;

  if command -v systemctl > /dev/null ; then
    services_enabled="\${services_enabled} zfs-import-cache zfs-mount zfs-import.target zfs.target" ;
  #elif command -v s6-rc > /dev/null ; then
  #  ?? services_enabled="\${services_enabled} zfs-mount" ;
  #
  elif command -v sv > /dev/null ; then
    mkdir -p /etc/runit/sv/zfs-mount/supervise ;
    cat << EOF >> /etc/runit/sv/zfs-mount/run ;
#!/bin/sh

zfs mount ${ZPOOLNM}/ROOT/default ; zfs mount -a

EOF

    chmod +x /etc/runit/sv/zfs-mount/run ;
    services_enabled="\${services_enabled} zfs-mount" ;
  elif command -v rc-update > /dev/null ; then
    mkdir -p /etc/init.d ;
    cat << EOF >> /etc/init.d/zfs-mount ;
#!/sbin/openrc-run

command="zfs mount ${ZPOOLNM}/ROOT/default ; zfs mount -a"

EOF

    chmod +x /etc/init.d/zfs-mount ;
    services_enabled="\${services_enabled} zfs-mount" ;
  fi ;

  sed -i '/^HOOKS/ s| keyboard||' /etc/mkinitcpio.conf ;
  #sed -i '/^HOOKS/ s|filesystems|keyboard encrypt zfs usr filesystems|' /etc/mkinitcpio.conf  # encrypt hook only if crypted root partition
  sed -i '/^HOOKS/ s|filesystems|keyboard zfs usr filesystems|' \
    /etc/mkinitcpio.conf ;

  echo "Hold zfs & kernel package upgrades (require manual upgrade)" ;
  sed -i 's|#IgnorePkg|IgnorePkg|' /etc/pacman.conf ;
  for pkgX in zfs-dkms zfs-utils linux\${LINSUF} linux\${LINSUF}-headers ; do
    sed -i "/^IgnorePkg/ s|\$| \${pkgX}|" /etc/pacman.conf
  done ;
  grep -e '^IgnorePkg' /etc/pacman.conf ; sleep 3 ;
elif [ "btrfs" = "${VOL_MGR}" ] ; then
  pacman -Sy --needed --noconfirm btrfs-progs ;
  modprobe btrfs ; sleep 5 ;
elif [ "lvm" = "${VOL_MGR}" ] ; then
  if [ "arch" = "\${ID}" ] || [ "archarm" = "\${ID}" ] ; then
    pacman -Sy --needed --noconfirm device-mapper lvm2 ;
    # cryptsetup mdadm
  elif [ "artix" = "\${ID}" ] || [ "armtix" = "\${ID}" ] ; then
    if command -v s6-rc > /dev/null ; then
      service_mgr=s6 ;
    elif command -v sv > /dev/null ; then
      service_mgr=runit ;
    elif command -v rc-update > /dev/null ; then
      service_mgr=openrc ;
    fi ;
    pacman -Sy --needed --noconfirm device-mapper-\${service_mgr} \
      lvm2-\${service_mgr} ;
    # cryptsetup-\${service_mgr} mdadm-\${service_mgr}
  fi ;
  modprobe dm-mod ; vgscan ; vgchange -ay ; lvs ; sleep 5 ;

  if command -v systemctl > /dev/null ; then
    services_enabled="\${services_enabled} dm-event lvm2-lvmpolld lvm2-monitor" ;
  elif command -v s6-rc > /dev/null ; then
    services_enabled="\${services_enabled} dmeventd-log dmevent-srv lvmpolld-log lvmpolld-srv lvm2-monitor" ;
  elif command -v sv > /dev/null ; then
    services_enabled="\${services_enabled} dmeventd" ;
  elif command -v rc-update > /dev/null ; then
    services_enabled="\${services_enabled} device-mapper lvm lvmpolld lvm-monitoring" ;
  fi ;

  sed -i '/^HOOKS/ s|filesystems|lvm2 filesystems|' /etc/mkinitcpio.conf ;
fi

for svc in \${services_enabled} ; do
  if command -v systemctl > /dev/null ; then
    systemctl enable \${svc} ;
  elif command -v s6-rc > /dev/null ; then
    s6-rc-bundle-update add default \${svc} ;
    s6-rc-bundle -c /etc/s6/rc/compiled add default \${svc} ;
  elif command -v sv > /dev/null ; then
    ln -s /etc/runit/sv/\${svc} /etc/runit/runsvdir/default/ ;
  elif command -v rc-update > /dev/null ; then
    rc-update add \${svc} boot ;
  fi
done

mkinitcpio -p linux\${LINSUF} #; mkinitcpio -P


grub-probe /boot

echo "Bootloader installation & config" ; sleep 3
mkdir -p /boot/efi/EFI/\${ID} /boot/efi/EFI/BOOT
if [ "aarch64" = "${UNAME_M}" ] ; then
  grub-install --target=arm64-efi --efi-directory=/boot/efi --bootloader-id=\${ID} --recheck --removable ;
  #cp /boot/efi/EFI/\${ID}/grubaa64.efi /boot/efi/EFI/BOOT/BOOTAA64.EFI ;
else
  grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=\${ID} --recheck --removable ;
  grub-install --target=i386-pc --recheck /dev/${DEVX} ;
  #cp /boot/efi/EFI/\${ID}/grubx64.efi /boot/efi/EFI/BOOT/BOOTX64.EFI ;
fi
find / -ipath /boot/efi/*/*.efi ; sleep 5

#sed -i -e "s|^GRUB_TIMEOUT=.*$|GRUB_TIMEOUT=1|" /etc/default/grub
#sed -i -e "/GRUB_DEFAULT/ s|=.*$|=saved|" /etc/default/grub
#echo "GRUB_SAVEDEFAULT=true" >> /etc/default/grub
sed -ie '/^GRUB_CMDLINE_LINUX_DEFAULT/ s|^\(.*\)$|#\1\n\1|' /etc/default/grub
sed -ie '/^GRUB_CMDLINE_LINUX_DEFAULT/ s|="\(.*\)"|="\1 xdriver=vesa rootdelay=5 resume=/dev/foo nomodeset text"|' /etc/default/grub
#sed -ie '/^GRUB_CMDLINE_LINUX_DEFAULT/ s|="\(.*\)"|="\1 video=1024x768 "|' /etc/default/grub

if [ "zfs" = "${VOL_MGR}" ] ; then
  sed -ie '/^GRUB_CMDLINE_LINUX_DEFAULT/ s| nomodeset| root=ZFS=${ZPOOLNM}/ROOT/default nomodeset|' /etc/default/grub ;
  echo 'GRUB_PRELOAD_MODULES="zfs"' >> /etc/default/grub ;
elif [ "btrfs" = "${VOL_MGR}" ] ; then
  echo 'GRUB_PRELOAD_MODULES="btrfs"' >> /etc/default/grub ;
elif [ "lvm" = "${VOL_MGR}" ] ; then
  echo 'GRUB_PRELOAD_MODULES="lvm"' >> /etc/default/grub ;
fi

if [ "\$(dmesg | grep -ie 'Hypervisor detected')" ] ; then
  sed -ie '/^GRUB_CMDLINE_LINUX_DEFAULT/ s|="\(.*\)"|="\1 net.ifnames=0 biosdevname=0"|' /etc/default/grub ;
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
  efibootmgr -c -d /dev/${DEVX} -p \$(lsblk -nlpo name,label,partlabel | sed -n '/ESP/ s|.*[sv]da\([0-9]*\).*|\1|p') -l "/EFI/\${ID}/grubaa64.efi" -L "\${ID}#${GRP_NM}"
  efibootmgr -c -d /dev/${DEVX} -p \$(lsblk -nlpo name,label,partlabel | sed -n '/ESP/ s|.*[sv]da\([0-9]*\).*|\1|p') -l "/EFI/BOOT/BOOTAA64.EFI" -L Default
else
  efibootmgr -c -d /dev/${DEVX} -p \$(lsblk -nlpo name,label,partlabel | sed -n '/ESP/ s|.*[sv]da\([0-9]*\).*|\1|p') -l "/EFI/\${ID}/grubx64.efi" -L "\${ID}#${GRP_NM}"
  efibootmgr -c -d /dev/${DEVX} -p \$(lsblk -nlpo name,label,partlabel | sed -n '/ESP/ s|.*[sv]da\([0-9]*\).*|\1|p') -l "/EFI/BOOT/BOOTX64.EFI" -L Default
fi
efibootmgr -v ; sleep 3

mkpasswd -m help ; sleep 10

pacman -Scc --noconfirm

exit

EOFchroot

  if [ "zfs" = "${VOL_MGR}" ] ; then
    zpool trim ${ZPOOLNM} ; zpool set autotrim=on ${ZPOOLNM} ;
  else
    fstrim -av ;
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
