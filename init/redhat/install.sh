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
# [9|9-stream]/BaseOS/x86_64/os
# (rocky) mirror: dl.rockylinux.org/pub/rocky
# (centos-stream) mirror: mirror.stream.centos.org
export RELEASE=${RELEASE:-9}
if [ $(echo ${RELEASE} | grep -e '-stream') ] ; then
  export MIRROR=${MIRROR:-mirror.stream.centos.org} ;
else
  export MIRROR=${MIRROR:-dl.rockylinux.org/pub/rocky} ;
fi
export UNAME_M=$(uname -m)

export YUMCMD="yum --setopt=requires_policy=strong --setopt=group_package_types=mandatory"
export DNFCMD="dnf --setopt=install_weak_deps=False"


# ifconfig [; ifconfig wlan create wlandev ath0 ; ifconfig wlan0 up scan]
# dhcpcd {ifdev}
# [networkctl status ; networkctl up {ifdev}]
# nmcli device status ; nmcli connection up {ifdev}

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
  if [ $(echo ${RELEASE} | grep -e '-stream') ] ; then
    RELEASE_MAJOR=$(echo ${RELEASE} | sed -n 's|\([0-9]*\).*|\1|p') ;
    curl --fail-early --fail -Lo /tmp/rootfs.tar.xz \
      https://cloud.centos.org/centos/${RELEASE}/${UNAME_M}/images/CentOS-Stream-Container-Base-${RELEASE_MAJOR}-latest.${UNAME_M}.tar.xz ;
    curl --fail-early --fail -Lo /tmp/rootfs.tar.xz.CHECKSUM \
      https://cloud.centos.org/centos/${RELEASE}/${UNAME_M}/images/CentOS-Stream-Container-Base-${RELEASE_MAJOR}-latest.${UNAME_M}.tar.xz.SHA256SUM ;
  else
    curl --fail-early --fail -Lo /tmp/rootfs.tar.xz \
      https://${MIRROR}/${RELEASE}/images/${UNAME_M}/Rocky-${RELEASE}-Container-Base.latest.${UNAME_M}.tar.xz ;
    curl --fail-early --fail -Lo /tmp/rootfs.tar.xz.CHECKSUM \
      https://${MIRROR}/${RELEASE}/images/${UNAME_M}/Rocky-${RELEASE}-Container-Base.latest.${UNAME_M}.tar.xz.CHECKSUM ;
  fi
  grep 'Container-Base' /tmp/rootfs.tar.xz.CHECKSUM | grep '^SHA256' \
    | sed -E 's|.*= ([a-z0-9]*)$|\1  rootfs.tar.xz|' > /tmp/CHECKSUM
  sha256sum --ignore-missing -c /tmp/CHECKSUM

  if [ $(echo ${RELEASE} | grep -e '-stream') ] ; then
    # extract docker image tarball format
    tar -xaJf /tmp/rootfs.tar.xz --strip-components 1 -C /tmp \
      --wildcards \*/layer.tar ;
    (cat /tmp/layer.tar | tar -xf - -C ${DESTDIR:-/mnt}) ;
  else
    #(cat /tmp/rootfs.tar.xz | tar --unlink -xpJf - -C ${DESTDIR:-/mnt}) ;
    (cat /tmp/rootfs.tar.xz | tar -xaJf - -C ${DESTDIR:-/mnt}) ;
  fi
}

bootstrap() {
  echo "Bootstrap base pkgs" ; sleep 3
  if [ "zfs" = "${VOL_MGR}" ] ; then
    zfs umount ${ZPOOLNM}/var/mail ; zfs destroy ${ZPOOLNM}/var/mail ;
  fi
  REPO_DIRECTORY=${REPO_DIRECTORY:-"/${RELEASE}/BaseOS/${UNAME_M}/os"}
  pkg_list="@core dnf dnf-plugins-core yum yum-utils" # basesystem
  if command -v dnf > /dev/null || command -v yum-config-manager > /dev/null ; then
    if command -v dnf > /dev/null ; then
      #${DNFCMD} --releasever=${RELEASE} --installroot=/mnt --nogpgcheck --repofrompath=quickrepo${RELEASE},http://${MIRROR}${REPO_DIRECTORY}/ --repo=quickrepo${RELEASE} install -y ${pkg_list} ;
      #${DNFCMD} --releasever=${RELEASE} --installroot=/mnt --nogpgcheck config-manager -y --set-disabled appstream baseos crb extras epel epel-cisco-openh264 ;
      ${DNFCMD} --releasever=${RELEASE} --installroot=/mnt --nogpgcheck config-manager -y --set-disabled '*' ;
      ${DNFCMD} --releasever=${RELEASE} --installroot=/mnt --nogpgcheck config-manager -y --add-repo http://${MIRROR}${REPO_DIRECTORY} ;
      ${DNFCMD} --installroot=/mnt check-update -y ;
      ${DNFCMD} --releasever=${RELEASE} --installroot=/mnt --nogpgcheck install -y ${pkg_list} ;
      ${DNFCMD} --installroot=/mnt repolist -y ;
    elif command -v yum-config-manager > /dev/null ; then
      rm -r /mnt/var/lib/rpm /mnt/var/cache/dnf ;
      mkdir -p /mnt/var/lib/rpm /mnt/var/cache/dnf ;
      rpm -v --root /mnt --initdb ;
      ##repos_ver=$(curl -Ls http://${MIRROR}${REPO_DIRECTORY}/Packages | sed -n 's|.*centos-stream-repos-\(.*\).rpm.*|\1|p') ;
      ## [wget -O file url | curl -Lo file url]
      ##wget -O /tmp/repos.rpm http://${MIRROR}${REPO_DIRECTORY}/Packages/centos-stream-repos-${repos_ver:-9.0-26.el9.noarch}.rpm ;
      #repos_ver=$(curl -Ls http://${MIRROR}${REPO_DIRECTORY}/Packages/r | sed -n 's|.*rocky-repos-\(.*\).rpm.*|\1|p') ;
      # [wget -O file url | curl -Lo file url]
      #wget -O /tmp/repos.rpm http://${MIRROR}${REPO_DIRECTORY}/Packages/r/rocky-repos-${repos_ver:-9.4-1.7.el9.noarch}.rpm ;
      #rpm -v -qip /tmp/repos.rpm ; sleep 5 ;
      #rpm -v --root /mnt --nodeps -i /tmp/repos.rpm ;
      #yum-config-manager --releasever=${RELEASE} --installroot=/mnt --nogpgcheck -y --set-disabled appstream baseos crb extras epel epel-cisco-openh264 ;
      yum-config-manager --releasever=${RELEASE} --installroot=/mnt --nogpgcheck -y --set-disabled '*' ;
      yum-config-manager --releasever=${RELEASE} --installroot=/mnt --nogpgcheck -y --add-repo http://${MIRROR}${REPO_DIRECTORY} ;
      ${YUMCMD} --installroot=/mnt check-update -y ;
      ${YUMCMD} --releasever=${RELEASE} --installroot=/mnt --nogpgcheck install -y ${pkg_list} ;
      ${YUMCMD} --installroot=/mnt repolist -y ;
    fi ;
  else
    mv /mnt/etc/fstab /mnt/etc/fstab.disk_setup ;
    _rootfs_extract ;
    cp -a /mnt/etc/fstab /mnt/etc/fstab.rootfs ;
    cp -a /mnt/etc/fstab.disk_setup /mnt/etc/fstab ;
    mv /mnt/etc/resolv.conf /mnt/etc/resolv.conf.rootfs ;
    cp /etc/resolv.conf /mnt/etc/resolv.conf ; cp /etc/mtab /mnt/etc/mtab ;
    # LANG=[C|en_US].UTF-8
    cat << EOFchroot | LANG=C.UTF-8 LANGUAGE=en ${CHROOT_CMD} /mnt /bin/sh ;
set -x

unalias -a

${DNFCMD} check-update -y
${DNFCMD} install -y --nogpgcheck --allowerasing ${pkg_list} 'dnf-command(config-manager)'
${DNFCMD} check-update -y ; ${DNFCMD} repolist -y

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
  #mkdir -p /mnt/var/empty /mnt/var/lock/subsys /mnt/etc/sysconfig/network-scripts
  #cp -a /etc/sysconfig/network-scripts/ifcfg-${ifdev} /mnt/etc/sysconfig/network-scripts/ifcfg-${ifdev}.bak
  ## temporarily disable SELinux to allow chpasswd in chroot
  #setenforce 0 ; sestatus ; sleep 5
  sleep 5
}

system_config() {
  export INIT_HOSTNAME=${1:-redhat-boxv0000}
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
${DNFCMD} --releasever=\${VERSION_MAJOR} install -y epel-release epel-next-release
${DNFCMD} --releasever=\${VERSION_MAJOR} install -y http://dl.fedoraproject.org/pub/epel/epel-release-latest-\${VERSION_MAJOR}.noarch.rpm http://dl.fedoraproject.org/pub/epel/epel-next-release-latest-\${VERSION_MAJOR}.noarch.rpm
${DNFCMD} config-manager -y --set-enabled appstream baseos crb extras epel epel-cisco-openh264
crb enable ; /usr/bin/crb enable
#cat /etc/yum.repos.d/* ; sleep 5
${DNFCMD} repolist -y ; sleep 5


services_enabled="sshd tmp.mount"
pkg_list="@core pciutils nano sudo tar kbd openssl systemd python3-dnf-plugin-versionlock python3-urllib3 'dnf-command(versionlock)'"
# @base @^minimal @minimal-environment redhat-lsb-core @xfce-desktop

echo "Add software package selection(s)" ; sleep 3
for pkgX in \${pkg_list} ; do
  ${DNFCMD} install -y \${pkgX} ;
done
for pkgX in lsb-release dhcpcd ; do
  ${DNFCMD} --enablerepo=epel install -y \${pkgX} ;
done

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
sed -i '/^127.0.1.1/ s|127.0.1.1|#127.0.1.1|' /etc/hosts
echo "127.0.1.1   ${INIT_HOSTNAME}.localdomain  ${INIT_HOSTNAME}" >> /etc/hosts

ifdev=\$(ip -o link | grep 'link/ether' | grep 'LOWER_UP' | sed -n 's|\S*: \(\w*\):.*|\1|p')

#sh -c "cat >> /etc/sysconfig/network-scripts/ifcfg-\${ifdev:-eth0}" << EOF
#BOOTPROTO=dhcp
#STARTMODE=auto
#ONBOOT=yes
#DHCP_CLIENT=dhclient
#
#EOF
sh -c "cat >> /etc/sysconfig/network" << EOF
NETWORKING=yes
CRDA_DOMAIN=US
HOSTNAME=${INIT_HOSTNAME}

EOF

echo "Config services" ; sleep 3

cp -a /usr/share/systemd/tmp.mount /etc/systemd/system/
#echo "tmpfs                           /tmp        tmpfs   defaults,nosuid,nodev,mode=1777   0   0" >> /etc/fstab

echo "Enable services" ; sleep 3
for svc in \${services_enabled} ; do
  systemctl enable \${svc} ;
done
#systemd-machine-id-setup --commit


echo "Set root passwd ; add user" ; sleep 3
#echo -n "root:${PASSWD_PLAIN}" | chpasswd
echo -n 'root:${PASSWD_CRYPTED}' | chpasswd -e

DIR_MODE=0750 useradd -m -G wheel -s /bin/bash -c 'Packer User' packer
#echo -n "packer:${PASSWD_PLAIN}" | chpasswd
echo -n 'packer:${PASSWD_CRYPTED}' | chpasswd -e
mkdir -m 0700 -p /home/packer/.ssh ; chown -R packer /home/packer

#sh -c 'cat | EDITOR="tee -a" visudo -f /etc/sudoers.d/99_packernopasswd' << EOF
##Defaults:packer !requiretty
#packer ALL=(ALL:ALL) NOPASSWD: ALL
#
#EOF
##chmod 0440 /etc/sudoers.d/99_packernopasswd


#sed -i "/^[^#].*requiretty/ s|^|#|" /etc/sudoers
cat << EOF | EDITOR="tee -a" visudo -f /etc/sudoers.d/99_wheelnopasswd
#Defaults:%wheel !requiretty
%wheel ALL=(ALL:ALL) NOPASSWD: ALL

EOF


echo "Config SELinux" ; sleep 3
touch /.autorelabel
sed -i 's|SELINUX=.*$|SELINUX=permissive|' /etc/sysconfig/selinux
sestatus ; sleep 5


${DNFCMD} clean -y packages

exit

EOFchroot
# end chroot commands
}

kernel_bootloader() {
  # LANG=[C|en_US].UTF-8
  cat << EOFchroot | LANG=C.UTF-8 LANGUAGE=en ${CHROOT_CMD} /mnt /bin/sh
set -x

. /etc/os-release ; VERSION_MAJOR=\$(echo \${VERSION_ID} | cut -d. -f1)

pkg_list="shim-* grub2-* efibootmgr"

${DNFCMD} check-update -y

if [ \$(echo ${RELEASE} | grep -e '-stream') ] ; then
  ${DNFCMD} install -y centos-release-kmods ;
  ${DNFCMD} check-update -y ;
  ${DNFCMD} install -y centos-release-kmods-kernel-6.6 ;
  ${DNFCMD} update -y ;
  ${DNFCMD} install -y kernel kernel-core kernel-modules kernel-tools kernel-tools-libs ;
  ${DNFCMD} install -y kernel-devel ;
else
  ## Use EL release kernel packages (avoid dkms build errors)
  #${DNFCMD} --enablerepo=epel install -y kernel kernel-devel ;
  #${DNFCMD} install -y kernel kernel-devel kernel-core kernel-modules ;
  ${DNFCMD} install -y elrepo-release ; ${DNFCMD} check-update -y ;
  ${DNFCMD} install --enablerepo=elrepo-kernel -y kernel-lt kernel-lt-core kernel-lt-modules kernel-lt-tools kernel-lt-tools-libs ;
  ${DNFCMD} install --enablerepo=elrepo-kernel -y kernel-lt-devel ;
fi

if [ "x86_64" = "${UNAME_M}" ] ; then
  pkg_list="\${pkg_list} microcode_ctl" ;
fi
#pkg_list="\${pkg_list} dracut-tools dracut-config-generic dracut-config-rescue"

for pkgX in \${pkg_list} ; do
  ${DNFCMD} install -y \${pkgX} ;
done

if [ "\$(dmesg | grep -ie 'Hypervisor detected')" ] ; then
  ${DNFCMD} remove -y linux-firmware iwl*-firmware ;
fi

#kver="\$(ls -A /lib/modules/ | tail -1)" # ?? or uname -r
if [ \$(echo ${RELEASE} | grep -e '-stream') ] ; then
  kver=\$(${DNFCMD} list -y --installed kernel | sed -n 's|kernel[a-z0-9._]*[ ]*\([^ ]*\)[ ]*.*$|\1|p' | tail -n1) ;
else
  kver=\$(${DNFCMD} list -y --installed kernel-lt | sed -n 's|kernel-lt[a-z0-9._]*[ ]*\([^ ]*\)[ ]*.*$|\1|p' | tail -n1) ;
fi
echo \${kver} ; sleep 5


echo "Config dracut"
echo 'hostonly="yes"' >> /etc/dracut.conf
mkdir -p /etc/dracut.conf.d

modprobe vfat ; lsmod | grep -e fat ; sleep 5

if [ "zfs" = "${VOL_MGR}" ] ; then
  #${DNFCMD} install -y dracut-tools dracut-config-generic dracut-config-rescue ;

  ${DNFCMD} install -y https://zfsonlinux.org/epel/zfs-release-2-3.el\${VERSION_MAJOR}.noarch.rpm ;
  ${DNFCMD} install -y https://zfsonlinux.org/epel/zfs-release-2-3\$(rpm --eval "%{dist}").noarch.rpm ;
  #rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-zfsonlinux ;
  #rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-openzfs ;

  ${DNFCMD} repolist -y ; sleep 5 ;

  #${DNFCMD} --enablerepo=epel,zfs-kmod --disablerepo=zfs install -y zfs zfs-dracut ;
  ${DNFCMD} --enablerepo=epel,zfs install -y zfs ;
  sleep 3 ;

  mkdir -p /etc/dkms ; echo REMAKE_INITRD=yes > /etc/dkms/zfs.conf ;
  zfs_ver=\$(zfs version | head -n1 | sed 's|zfs-||') ;
  dkms install --verbose zfs/\${zfs_ver} -k \${kver}.${UNAME_M} ;
  dkms status ; modprobe zfs ; zfs version ; sleep 5 ;

  zgenhostid -f -o /etc/hostid ; sleep 5 ;

  for presetX in zfs-import-cache zfs-mount zfs-zed zfs-import.target zfs.target ; do
    systemctl preset \${presetX} ;
  done ;

  for svc in zfs-import-cache zfs-mount zfs-import.target zfs.target ; do
    systemctl enable \${svc} ;
  done ;
  sleep 10 ;

  echo 'nofsck="yes"' >> /etc/dracut.conf.d/zol.conf ;
  echo 'add_dracutmodules+=" zfs "' >> /etc/dracut.conf.d/zol.conf ;
  echo 'force_drivers+=" zfs "' >> /etc/dracut.conf.d/zol.conf ;
  echo 'omit_dracutmodules+=" btrfs resume "' >> /etc/dracut.conf.d/zol.conf ;

  echo zfs > /etc/modules-load.d/zfs.conf ; # ??

  echo "Hold zfs & kernel package upgrades (require manual upgrade)" ;
  #${DNFCMD} versionlock -y add zfs zfs-dkms zfs-dracut kernel kernel-core \
  #  kernel-modules kernel-tools kernel-tools-libs kernel-devel kernel-headers ;
  ${DNFCMD} versionlock -y add zfs zfs-dkms zfs-dracut kernel kernel-* ;
  ${DNFCMD} versionlock -y list ; sleep 3 ;
elif [ "btrfs" = "${VOL_MGR}" ] ; then
  ${DNFCMD} --enablerepo=epel install -y btrfs-progs ;
  modprobe btrfs ; modinfo btrfs | grep -e name -e version -e vermagic ; sleep 5 ;
elif [ "lvm" = "${VOL_MGR}" ] ; then
  ${DNFCMD} install -y lvm2 ;
  # cryptsetup
  modprobe dm-mod ; lvm version ; vgscan ; vgchange -ay ; lvs ; sleep 5 ;
fi

dracut --force --kver \${kver}.${UNAME_M}


grub2-probe /boot

echo "Bootloader installation & config" ; sleep 3
mkdir -p /boot/efi/EFI/\${ID} /boot/efi/EFI/BOOT
if [ "aarch64" = "${UNAME_M}" ] ; then
  grub2-install --force --target=arm64-efi --efi-directory=/boot/efi --bootloader-id=\${ID} --recheck --removable ;
  #cp -R /boot/efi/EFI/\${ID}/* /boot/efi/EFI/BOOT/ ;
  #cp /boot/efi/EFI/BOOT/BOOTAA64.EFI /boot/efi/EFI/BOOT/BOOTAA64.EFI.bak ;
  #cp /boot/efi/EFI/BOOT/grubaa64.EFI /boot/efi/EFI/BOOT/BOOTAA64.EFI ;
  ##cp /boot/efi/EFI/\${ID}/grubaa64.efi /boot/efi/EFI/BOOT/BOOTAA64.EFI ;
else
  grub2-install --force --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=\${ID} --recheck --removable ;
  grub2-install --force --target=i386-pc --recheck /dev/${DEVX} ;
  #cp -R /boot/efi/EFI/\${ID}/* /boot/efi/EFI/BOOT/ ;
  #cp /boot/efi/EFI/BOOT/BOOTX64.EFI /boot/efi/EFI/BOOT/BOOTX64.EFI.bak ;
  #cp /boot/efi/EFI/BOOT/grubx64.EFI /boot/efi/EFI/BOOT/BOOTX64.EFI ;
  ##cp /boot/efi/EFI/\${ID}/grubx64.efi /boot/efi/EFI/BOOT/BOOTX64.EFI ;
fi
find / -ipath /boot/efi/*/*.efi ; sleep 5

cp -a /etc/default/grub /etc/default/grub.orig
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

#sed -ie "s|^GRUB_TIMEOUT=.*$|GRUB_TIMEOUT=1|" /etc/default/grub
#sed -ie "/GRUB_DEFAULT/ s|=.*$|=saved|" /etc/default/grub
#echo "GRUB_SAVEDEFAULT=true" >> /etc/default/grub
#echo "#GRUB_CMDLINE_LINUX='cryptdevice=/dev/sda2:cryptroot'" >> /etc/default/grub
sed -ie '/^GRUB_CMDLINE_LINUX_DEFAULT/ s|^\(.*\)$|#\1\n\1|' /etc/default/grub
sed -ie '/^GRUB_CMDLINE_LINUX_DEFAULT/ s|="\(.*\)"|="\1 xdriver=vesa rootdelay=5 nomodeset text"|' \
  /etc/default/grub

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
grub2-mkconfig -o /boot/grub2/grub.cfg
cp -f /boot/grub2/grub.cfg /boot/efi/EFI/\${ID}/grub.cfg
cp -f /boot/grub2/grub.cfg /boot/efi/EFI/BOOT/grub.cfg

if [ "aarch64" = "${UNAME_M}" ] ; then
  efibootmgr -c -d /dev/${DEVX} -p \$(lsblk -nlpo name,label,partlabel | sed -n '/ESP/ s|.*[sv]da\([0-9]*\).*|\1|p') -l "/EFI/\${ID}/grubaa64.efi" -L "\${ID}#${GRP_NM}"
  efibootmgr -c -d /dev/${DEVX} -p \$(lsblk -nlpo name,label,partlabel | sed -n '/ESP/ s|.*[sv]da\([0-9]*\).*|\1|p') -l "/EFI/BOOT/BOOTAA64.EFI" -L Default
else
  efibootmgr -c -d /dev/${DEVX} -p \$(lsblk -nlpo name,label,partlabel | sed -n '/ESP/ s|.*[sv]da\([0-9]*\).*|\1|p') -l "/EFI/\${ID}/grubx64.efi" -L "\${ID}#${GRP_NM}"
  efibootmgr -c -d /dev/${DEVX} -p \$(lsblk -nlpo name,label,partlabel | sed -n '/ESP/ s|.*[sv]da\([0-9]*\).*|\1|p') -l "/EFI/BOOT/BOOTX64.EFI" -L Default
fi
efibootmgr -v ; sleep 3

${DNFCMD} install -y mkpasswd
mkpasswd -m help ; sleep 10

${DNFCMD} clean -y all

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
