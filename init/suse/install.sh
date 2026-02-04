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


# ifconfig [; ifconfig wlan create wlandev ath0 ; ifconfig wlan0 up scan]
# dhcpcd {ifdev}
# [networkctl status ; networkctl up {ifdev}]
# nmcli device status ; nmcli connection up {ifdev}
# [wicked ifstatus all ; wicked ifup {ifdev}]

#ntpd -u ntp:ntp ; ntpq -p ; timedatectl ; sleep 3
#chronyd -u ntp:ntp ; chronyc -N sources ; sleep 3
#chronyd -q # ntpdate -v -u -b us.pool.ntp.org

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
  if [ "tumbleweed" = "${RELEASE}" ] || [ "slowroll" = "${RELEASE}" ] ; then
    curl -LO \
      http://${MIRROR}/tumbleweed/appliances/opensuse-tumbleweed-image.${UNAME_M}-lxc.tar.xz ;
    ln -s opensuse-tumbleweed-image.${UNAME_M}-lxc.tar.xz rootfs.tar.xz ;
    curl -Lo /tmp/rootfs.tar.xz.CHECKSUM \
      http://${MIRROR}/tumbleweed/appliances/opensuse-tumbleweed-image.${UNAME_M}-lxc.tar.xz.sha256 ;
  else
    curl -LO \
      http://${MIRROR}/distribution/${RELEASE}/appliances/opensuse-leap-image.${UNAME_M}-lxc.tar.xz ;
    ln -s opensuse-leap-image.${UNAME_M}-lxc.tar.xz rootfs.tar.xz ;
    curl -Lo /tmp/rootfs.tar.xz.CHECKSUM \
      http://${MIRROR}/distribution/${RELEASE}/appliances/opensuse-leap-image.${UNAME_M}-lxc.tar.xz.sha256 ;
  fi
  grep 'opensuse.*.tar.xz' /tmp/rootfs.tar.xz.CHECKSUM \
    | sed -E 's|([a-z0-9]*) .*$|\1  rootfs.tar.xz|' > /tmp/CHECKSUM
  sha256sum --ignore-missing -c /tmp/CHECKSUM

  #(cat /tmp/rootfs.tar.xz | tar --unlink -xpJf - -C ${DESTDIR:-/mnt})
  (cat /tmp/rootfs.tar.xz | tar -xaJf - -C ${DESTDIR:-/mnt})
}

bootstrap() {
  echo "Bootstrap base pkgs" ; sleep 3
  if [ "zfs" = "${VOL_MGR}" ] ; then
    zfs umount ${ZPOOLNM}/var/mail ; zfs destroy ${ZPOOLNM}/var/mail ;
  elif [ "btrfs" = "${VOL_MGR}" ] ; then
    umount /mnt/var/mail ; rm -fr /mnt/var/mail ;
    mkdir -p /mnt/var/spool/mail ;
    DEV_PV=$(lsblk -nlpo name,partlabel | grep -e ${PV_NM:-pvol0} | cut -d' ' -f1) ;
    mount -o noatime,compress=lzo,subvol=@/var_mail ${DEV_PV} /mnt/var/spool/mail ;
    sed -i 's|/var/mail|/var/spool/mail|' /mnt/etc/fstab* ;
  fi
  # patterns-base-base --> --type pattern base --> +pattern:base
  pkg_list="+pattern:base system-group-wheel makedev"
  if command -v zypper > /dev/null ; then
    #rm -r /mnt/var/lib/rpm /mnt/var/cache/zypp ;
    #mkdir -p /mnt/var/lib/rpm /mnt/var/cache/zypp ;
    #rpm -v --root /mnt --initdb ;
    #release_ver=$(curl -Ls http://${MIRROR}/distribution/${RELEASE}/repo/oss/${UNAME_M} | sed -n 's|.*openSUSE-release-\(.*\).rpm.*|\1|p') ;
    # [wget -O file url | curl -Lo file url]
    #wget -O /tmp/release.rpm http://${MIRROR}/distribution/${RELEASE}/repo/oss/${UNAME_M}/openSUSE-release-${release_ver:-15.4-lp154.153.1.${UNAME_M}}.rpm ;
    #rpm -v -qip /tmp/release.rpm ; sleep 5 ;
    #rpm -v --root /mnt --nodeps -i /tmp/release.rpm ;
    if [ "tumbleweed" = "${RELEASE}" ] ; then
      zypper --non-interactive --root /mnt --gpg-auto-import-keys addrepo http://${MIRROR}/tumbleweed/repo/oss/ repo-oss
      zypper --non-interactive --root /mnt --gpg-auto-import-keys addrepo http://${MIRROR}/tumbleweed/repo/non-oss/ repo-non-oss
      zypper --non-interactive --root /mnt --gpg-auto-import-keys addrepo http://${MIRROR}/update/tumbleweed/ update-oss
      zypper --non-interactive --root /mnt --gpg-auto-import-keys addrepo http://${MIRROR}/update/tumbleweed-non-oss/ update-non-oss
    elif [ "slowroll" = "${RELEASE}" ] ; then
      zypper --non-interactive --root /mnt --gpg-auto-import-keys addrepo http://${MIRROR}/slowroll/repo/oss/ repo-oss
      zypper --non-interactive --root /mnt --gpg-auto-import-keys addrepo http://${MIRROR}/slowroll/repo/non-oss/ repo-non-oss
      zypper --non-interactive --root /mnt --gpg-auto-import-keys addrepo http://${MIRROR}/update/slowroll/repo/oss/ update-oss
      #zypper --non-interactive --root /mnt --gpg-auto-import-keys addrepo http://${MIRROR}/update/slowroll/repo/non-oss/ update-non-oss # ???
    else
      zypper --non-interactive --root /mnt --gpg-auto-import-keys addrepo http://${MIRROR}/distribution/openSUSE-current/repo/oss/ repo-oss
    zypper --non-interactive --root /mnt --gpg-auto-import-keys addrepo http://${MIRROR}/distribution/openSUSE-current/repo/non-oss/ repo-non-oss
    zypper --non-interactive --root /mnt --gpg-auto-import-keys addrepo http://${MIRROR}/update/openSUSE-current/ update-oss
    zypper --non-interactive --root /mnt --gpg-auto-import-keys addrepo http://${MIRROR}/update/openSUSE-non-oss-current/ update-non-oss
    fi ;
    zypper --non-interactive --root /mnt --gpg-auto-import-keys refresh
    zypper --no-refresh --ignore-unknown --non-interactive --root /mnt install -y --no-recommends --allow-downgrade ${pkg_list} ;
    zypper --no-refresh --non-interactive --root /mnt repos ;
  else
    mv /mnt/etc/fstab /mnt/etc/fstab.disk_setup ;
    _rootfs_extract ;
    cp -a /mnt/etc/fstab /mnt/etc/fstab.rootfs ;
    mv /mnt/etc/fstab.disk_setup /mnt/etc/fstab ;
    mv /mnt/etc/resolv.conf /mnt/etc/resolv.conf.rootfs ;
    cp /etc/resolv.conf /mnt/etc/resolv.conf ; cp /etc/mtab /mnt/etc/mtab ;
    # LANG=[C|en_US].UTF-8
    cat << EOFchroot | LANG=C.UTF-8 LANGUAGE=en ${CHROOT_CMD} /mnt /bin/sh ;
set -x

unalias -a

if [ "slowroll" = "${RELEASE}" ] ; then
  zypper --no-refresh --non-interactive removerepo repo-oss repo-non-oss repo-update repo-debug repo-source update-oss update-non-oss
  zypper --no-refresh --non-interactive --gpg-auto-import-keys addrepo http://${MIRROR}/slowroll/repo/oss/ repo-oss
  zypper --no-refresh --non-interactive --gpg-auto-import-keys addrepo http://${MIRROR}/slowroll/repo/non-oss/ repo-non-oss
  zypper --no-refresh --non-interactive --gpg-auto-import-keys addrepo http://${MIRROR}/update/slowroll/repo/oss/ update-oss
  #zypper --no-refresh --non-interactive --gpg-auto-import-keys addrepo http://${MIRROR}/update/slowroll/repo/non-oss/ update-non-oss # ??
fi

zypper --non-interactive --gpg-auto-import-keys refresh
if [ "slowroll" = "${RELEASE}" ] ; then
  zypper --no-refresh --non-interactive install -y openSUSE-repos-Slowroll distribution-logos-openSUSE-Slowroll ;
  zypper --no-refresh --non-interactive install -y --oldpackage openSUSE-release ;
fi
zypper --no-refresh --ignore-unknown --non-interactive install -y --no-recommends --allow-downgrade ${pkg_list}
zypper --non-interactive --gpg-auto-import-keys refresh
zypper --no-refresh --non-interactive repos

exit

EOFchroot
  fi
  sleep 5

  cp /etc/mtab /mnt/etc/mtab
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
  #mkdir -p /mnt/var/empty /mnt/var/lock/subsys /mnt/etc/sysconfig/network
  #cp -a /etc/sysconfig/network/ifcfg-${ifdev} /mnt/etc/sysconfig/network/ifcfg-${ifdev}.bak
  mkdir -p /mnt/run/netconfig ; touch /mnt/run/netconfig/resolv.conf
  sleep 5
}

system_config() {
  export INIT_HOSTNAME=${1:-suse-boxv0000}
  #export PASSWD_PLAIN=${2:-packer}
  export PASSWD_CRYPTED=${2:-\$6\$16CHARACTERSSALT\$A4i3yeafzCxgDj5imBx2ZdMWnr9LGzn3KihP9Dz0zTHbxw31jJGEuuJ6OB6Blkkw0VSUkQzSjE9n4iAAnl0RQ1}

  # LANG=[C|en_US].UTF-8
  cat << EOFchroot | LANG=C.UTF-8 LANGUAGE=en ${CHROOT_CMD} /mnt /bin/sh
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

zypper --non-interactive --gpg-auto-import-keys refresh
if [ "tumbleweed" = "${RELEASE}" ] ; then
  zypper --no-refresh --non-interactive --gpg-auto-import-keys addrepo http://${MIRROR}/tumbleweed/repo/oss/ repo-oss
  zypper --no-refresh --non-interactive --gpg-auto-import-keys addrepo http://${MIRROR}/tumbleweed/repo/non-oss/ repo-non-oss
  zypper --no-refresh --non-interactive --gpg-auto-import-keys addrepo http://${MIRROR}/update/tumbleweed/ update-oss
  zypper --no-refresh --non-interactive --gpg-auto-import-keys addrepo http://${MIRROR}/update/tumbleweed-non-oss/ update-non-oss
elif [ "slowroll" = "${RELEASE}" ] ; then
  zypper --no-refresh --non-interactive --gpg-auto-import-keys addrepo http://${MIRROR}/slowroll/repo/oss/ repo-oss
  zypper --no-refresh --non-interactive --gpg-auto-import-keys addrepo http://${MIRROR}/slowroll/repo/non-oss/ repo-non-oss
  zypper --no-refresh --non-interactive --gpg-auto-import-keys addrepo http://${MIRROR}/update/slowroll/repo/oss/ update-oss
  #zypper --no-refresh --non-interactive --gpg-auto-import-keys addrepo http://${MIRROR}/update/slowroll/repo/non-oss/ update-non-oss # ???
else # elif [ "opensuse-leap" = "\${ID}" ] ; then
  zypper --no-refresh --non-interactive --gpg-auto-import-keys addrepo http://${MIRROR}/distribution/leap/\${VERSION_ID}/repo/oss/ repo-oss
  zypper --no-refresh --non-interactive --gpg-auto-import-keys addrepo http://${MIRROR}/distribution/leap/\${VERSION_ID}/repo/non-oss/ repo-non-oss
  zypper --no-refresh --non-interactive --gpg-auto-import-keys addrepo http://${MIRROR}/update/leap/\${VERSION_ID}/oss/ update-oss
  zypper --no-refresh --non-interactive --gpg-auto-import-keys addrepo http://${MIRROR}/update/leap/\${VERSION_ID}/non-oss/ update-non-oss
fi

zypper --no-refresh --non-interactive repos ; sleep 5


services_enabled="sshd tmp.mount"
# patterns-base-base --> --type pattern base --> +pattern:base
pkg_list="+pattern:base lsb-release system-group-wheel pciutils sudo whois nano less dosfstools xfsprogs wicked debianutils openssl openssh makedev openssh-askpass python312 python312-urllib3"
# patterns-xfce-xfce --> --type pattern xfce --> +pattern:xfce

echo "Add software package selection(s)" ; sleep 3
zypper --non-interactive --gpg-auto-import-keys refresh
if [ "slowroll" = "${RELEASE}" ] ; then
  zypper --no-refresh --ignore-unknown --non-interactive install -y openSUSE-repos-Slowroll distribution-logos-openSUSE-Slowroll ;
  zypper --no-refresh --ignore-unknown --non-interactive install -y --oldpackage openSUSE-release ;
fi
zypper --no-refresh --ignore-unknown --non-interactive install -y --no-recommends ca-certificates-cacert ca-certificates-mozilla
zypper --non-interactive --gpg-auto-import-keys refresh
update-ca-certificates

zypper --no-refresh --ignore-unknown --non-interactive install -y --no-recommends --allow-downgrade \${pkg_list}
zypper --no-refresh --ignore-unknown --non-interactive install -y --no-recommends --allow-downgrade openssh
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
sed -i '/^127.0.1.1/ s|127.0.1.1|#127.0.1.1|' /etc/hosts
echo "127.0.1.1   ${INIT_HOSTNAME}.localdomain  ${INIT_HOSTNAME}" >> /etc/hosts

ifdev=\$(ip -o link | grep 'link/ether' | grep 'LOWER_UP' | sed -n 's|\S*: \(\w*\):.*|\1|p')

sh -c "cat >> /etc/sysconfig/network/ifcfg-\${ifdev:-eth0}" << EOF
BOOTPROTO='dhcp'
STARTMODE='auto'
ONBOOT='yes'

EOF
echo "NETWORKING=yes" >> /etc/sysconfig/network

echo "Config services" ; sleep 3

cp -a /usr/share/systemd/tmp.mount /etc/systemd/system/
#echo "tmpfs                           /tmp        tmpfs   defaults,nosuid,nodev,mode=1777   0   0" >> /etc/fstab

echo "Enable services" ; sleep 3
for svc in \${services_enabled} ; do
  systemctl enable \${svc} ;
done
#systemd-machine-id-setup --commit


echo "Set root passwd ; add user" ; sleep 3
groupadd --system wheel
#echo -n "root:${PASSWD_PLAIN}" | chpasswd
echo -n 'root:${PASSWD_CRYPTED}' | chpasswd -e

DIR_MODE=0750 useradd -m -G wheel -s /bin/bash -c 'Packer User' packer
#echo -n "packer:${PASSWD_PLAIN}" | chpasswd
echo -n 'packer:${PASSWD_CRYPTED}' | chpasswd -e
mkdir -m 0700 -p /home/packer/.ssh ; chown -R packer /home/packer

sudoers_base=/etc/sudoers
#if [ -e "/usr/etc/sudoers" ] ; then
#  sudoers_base=/usr/etc/sudoers ;
#fi
echo "@includedir \${sudoers_base}.d" >> \${sudoers_base}
mkdir -p \${sudoers_base}.d
#sh -c 'cat | EDITOR="tee -a" visudo -f \${sudoers_base}.d/99_packernopasswd' << EOF
##Defaults:packer !requiretty
#packer ALL=(ALL:ALL) NOPASSWD: ALL
#
#EOF
##chmod 0440 \${sudoers_base}.d/99_packernopasswd


#sed -i '/^[^#].*requiretty/ s|^|#|' \${sudoers_base}
cat << EOF | EDITOR="tee -a" visudo -f \${sudoers_base}.d/99_wheelnopasswd
#Defaults:%wheel !requiretty
%wheel ALL=(ALL:ALL) NOPASSWD: ALL

EOF
cat << EOF | EDITOR="tee -a" visudo -f \${sudoers_base}.d/99_securepath
Defaults secure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

EOF


zypper --no-refresh --non-interactive clean

exit

EOFchroot
# end chroot commands
}

kernel_bootloader() {
# LANG=[C|en_US].UTF-8
cat << EOFchroot | LANG=C.UTF-8 LANGUAGE=en ${CHROOT_CMD} /mnt /bin/sh
set -x

. /etc/os-release

if [ "tumbleweed" = "${RELEASE}" ] || [ "slowroll" = "${RELEASE}" ] ; then
  LINSUF=-longterm ;
else
  LINSUF=-default ;
fi

# patterns-base-bootloader --> --type pattern bootloader --> +pattern:bootloader
# patterns-yast-yast2_basis --> --type pattern yast2_basis --> +pattern:yast2_basis
pkg_list="+pattern:bootloader +pattern:yast2_basis dracut-tools dracut kernel\${LINSUF} grub2 shim efibootmgr"

##zypper --no-refresh --ignore-unknown --non-interactive remove busybox-sed busybox-grep # ???
zypper --no-refresh --ignore-unknown --non-interactive install -y --force-resolution --no-recommends +pattern:bootloader +pattern:yast2_basis

zypper --no-refresh --ignore-unknown --non-interactive install -y --allow-downgrade \${pkg_list}
if [ ! "\$(dmesg | grep -iE 'kvm|qemu|hypervisor')" ] ; then
  zypper --no-refresh --non-interactive install -y kernel-firmware ;
fi
if [ "\$(dmesg | grep -iE 'kvm|qemu|hypervisor')" ] ; then
  zypper --no-refresh --non-interactive remove -y kernel-firmware* ;
fi

kver="\$(ls -A /lib/modules/ | tail -1)" # ?? or uname -r
echo \${kver} ; sleep 5

echo "Config dracut ; Linux kernel"
echo 'hostonly="yes"' >> /etc/dracut.conf
mkdir -p /etc/dracut.conf.d

modprobe vfat ; lsmod | grep -e fat ; sleep 5

if [ "zfs" = "${VOL_MGR}" ] ; then
  ## temp downgrade grub2[x86_64-efi|i386-pc] due to unknown filesystem error (ZFS)
  #zypper --no-refresh --ignore-unknown --non-interactive install -y --from repo-oss --from repo-non-oss --oldpackage grub2-i386-pc grub2-x86_64-efi shim grub2 ;
  #zypper addlock grub2-i386-pc grub2-x86_64-efi shim grub2 ;

  if [ "tumbleweed" = "${RELEASE}" ] ; then
    zypper --non-interactive --gpg-auto-import-keys addrepo http://${MIRROR}/repositories/filesystems/openSUSE_Tumbleweed/filesystems.repo ;
  elif [ "slowroll" = "${RELEASE}" ] ; then
    zypper --non-interactive --gpg-auto-import-keys addrepo http://${MIRROR}/repositories/filesystems/openSUSE_Slowroll/filesystems.repo ;
  else
    zypper --non-interactive --gpg-auto-import-keys addrepo http://${MIRROR}/repositories/filesystems/\${VERSION_ID}/filesystems.repo ;
  fi ;
  zypper --non-interactive --gpg-auto-import-keys refresh ;

  zypper --no-refresh --ignore-unknown --non-interactive install -y kernel\${LINSUF}-devel dkms zfs ;
  zypper --no-refresh --ignore-unknown --non-interactive install -y zfs ;

  # ?? Error - no zfs.ko module, just binaries zfs, zpool, etc (zfs ver 2.1.2)
  find /lib/modules -type f -name '*zfs.ko*' ;
  sleep 30 ; # ?? missing zfs.ko (zfs ver 2.1.2)

  mkdir -p /etc/dkms ; echo REMAKE_INITRD=yes > /etc/dkms/zfs.conf ;
  zfs_ver=\$(zfs version | head -n1 | sed 's|zfs-||') ;
  dkms install --verbose zfs/\${zfs_ver} -k \${kver}.${UNAME_M} ;
  dkms status ; modprobe zfs ; zfs version ; sleep 5 ;

  zgenhostid -f -o /etc/hostid ; sleep 5 ;

  sed -i '/^\[Unit\]/,/^$/!b;/^$/i\Requires=systemd-modules-load.service\nAfter=systemd-modules-load.service' \
    /etc/systemd/system/zfs-import.target.wants/zfs-import-cache.service ;
  sed -i '/^\[Service\]/,/^$/!b;/^$/i\ExecStartPre=/usr/bin/sleep 30' \
    /etc/systemd/system/zfs-import.target.wants/zfs-import-cache.service ;

  for svc in zfs-import-scan zfs-import-cache systemd-modules-load zfs-mount zfs.target ; do # zfs-import.target
    systemctl enable \${svc} ;
  done ;
  sleep 10 ;

  echo 'nofsck="yes"' >> /etc/dracut.conf.d/zol.conf ;
  echo 'add_dracutmodules+=" zfs "' >> /etc/dracut.conf.d/zol.conf ;
  echo 'omit_dracutmodules+=" btrfs resume "' >> /etc/dracut.conf.d/zol.conf ;

  echo "zfs" >> /etc/modules-load.d/zfs.conf ;
  dracut_extra_opts='--add-drivers "zfs"' ;

  echo "Hold zfs & kernel package upgrades (require manual upgrade)" ;
  zypper --no-refresh --non-interactive addlock zfs zfs-sudo kernel\${LINSUF} kernel\${LINSUF}-devel ;
  zypper --no-refresh --non-interactive locks ; sleep 3 ;
elif [ "btrfs" = "${VOL_MGR}" ] ; then
  zypper --no-refresh --ignore-unknown --non-interactive install -y btrfsprogs ;
  modprobe btrfs ; sleep 5 ;
elif [ "lvm" = "${VOL_MGR}" ] ; then
  zypper --no-refresh --ignore-unknown --non-interactive install -y lvm2 ;
  # cryptsetup
  modprobe dm-mod ; vgscan ; vgchange -ay ; lvs ; sleep 5 ;
fi

sleep 10
kernel-install add \${kver} /boot/vmlinuz-\${kver}

#mkinitrd /boot/initrd-\${kver}.img \${kver}
dracut --force \${dracut_extra_opts} --kver \${kver}
#zypper --no-refresh --ignore-unknown --non-interactive install -y -f kernel\${LINSUF}


grub2-probe /boot

echo "Bootloader installation & config" ; sleep 3
mkdir -p /boot/efi/EFI/\${ID} /boot/efi/EFI/BOOT
if [ "aarch64" = "${UNAME_M}" ] ; then
  grub2-install --target=arm64-efi --efi-directory=/boot/efi --bootloader-id=\${ID} --recheck --removable ;
  #cp -R /boot/efi/EFI/\${ID}/* /boot/efi/EFI/BOOT/ ;
  #cp /boot/efi/EFI/BOOT/BOOTAA64.EFI /boot/efi/EFI/BOOT/BOOTAA64.EFI.bak ;
  #cp /boot/efi/EFI/BOOT/grubaa64.EFI /boot/efi/EFI/BOOT/BOOTAA64.EFI ;
  ##cp /boot/efi/EFI/\${ID}/grubaa64.efi /boot/efi/EFI/BOOT/BOOTAA64.EFI ;
else
  grub2-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=\${ID} --recheck --removable ;
  grub2-install --target=i386-pc --recheck /dev/${DEVX} ;
  #cp -R /boot/efi/EFI/\${ID}/* /boot/efi/EFI/BOOT/ ;
  #cp /boot/efi/EFI/BOOT/BOOTX64.EFI /boot/efi/EFI/BOOT/BOOTX64.EFI.bak ;
  #cp /boot/efi/EFI/BOOT/grubx64.EFI /boot/efi/EFI/BOOT/BOOTX64.EFI ;
  ##cp /boot/efi/EFI/\${ID}/grubx64.efi /boot/efi/EFI/BOOT/BOOTX64.EFI ;
fi
find / -ipath /boot/efi/*/*.efi ; sleep 5

#sed -ie 's|^GRUB_TIMEOUT=.*$|GRUB_TIMEOUT=1|' /etc/default/grub
#sed -ie '/GRUB_DEFAULT/ s|=.*$|=saved|' /etc/default/grub
#echo "GRUB_SAVEDEFAULT=true" >> /etc/default/grub
#echo "#GRUB_CMDLINE_LINUX='cryptdevice=/dev/sda2:cryptroot'" >> /etc/default/grub
sed -ie '/^GRUB_CMDLINE_LINUX_DEFAULT/ s|^\(.*\)$|#\1\n\1|' /etc/default/grub
sed -ie '/^GRUB_CMDLINE_LINUX_DEFAULT/ s|="\(.*\)"|="\1 xdriver=vesa rootdelay=5 nomodeset text"|'  \
  /etc/default/grub

if [ "zfs" = "${VOL_MGR}" ] ; then
  sed -ie '/^GRUB_CMDLINE_LINUX_DEFAULT/ s| nomodeset| root=ZFS=${ZPOOLNM}/ROOT/default nomodeset|' /etc/default/grub ;
  echo 'GRUB_PRELOAD_MODULES="zfs"' >> /etc/default/grub ;
elif [ "btrfs" = "${VOL_MGR}" ] ; then
  echo 'GRUB_PRELOAD_MODULES="btrfs"' >> /etc/default/grub ;
elif [ "lvm" = "${VOL_MGR}" ] ; then
  echo 'GRUB_PRELOAD_MODULES="lvm"' >> /etc/default/grub ;
fi

if [ "\$(dmesg | grep -iE 'kvm|qemu|hypervisor')" ] ; then
  sed -ie '/^GRUB_CMDLINE_LINUX_DEFAULT/ s|="\(.*\)"|="\1 net.ifnames=0 biosdevname=0"|' /etc/default/grub ;
fi
grub2-mkconfig -o /boot/grub2/grub.cfg
#cp -f /boot/efi/EFI/\${ID}/grub.cfg /boot/grub2/grub.cfg
#cp -f /boot/efi/EFI/\${ID}/grub.cfg /boot/efi/EFI/BOOT/grub.cfg

if [ "aarch64" = "${UNAME_M}" ] ; then
  efibootmgr -c -d /dev/${DEVX} -p \$(lsblk -nlpo name,label,partlabel | sed -n '/ESP/ s|.*[sv]da\([0-9]*\).*|\1|p') -l "/EFI/\${ID}/grubaa64.efi" -L "\${ID}#${GRP_NM}"
  efibootmgr -c -d /dev/${DEVX} -p \$(lsblk -nlpo name,label,partlabel | sed -n '/ESP/ s|.*[sv]da\([0-9]*\).*|\1|p') -l "/EFI/BOOT/BOOTAA64.EFI" -L Default
else
  efibootmgr -c -d /dev/${DEVX} -p \$(lsblk -nlpo name,label,partlabel | sed -n '/ESP/ s|.*[sv]da\([0-9]*\).*|\1|p') -l "/EFI/\${ID}/grubx64.efi" -L "\${ID}#${GRP_NM}"
  efibootmgr -c -d /dev/${DEVX} -p \$(lsblk -nlpo name,label,partlabel | sed -n '/ESP/ s|.*[sv]da\([0-9]*\).*|\1|p') -l "/EFI/BOOT/BOOTX64.EFI" -L Default
fi
efibootmgr -v ; sleep 3

mkpasswd -m help ; sleep 10

zypper --no-refresh --non-interactive clean --all

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
