#!/bin/sh -x

# passwd crypted hash: [md5|sha256|sha512] - [$1|$5|$6]$...
# stty -echo ; openssl passwd -6 -salt 16CHARACTERSSALT -stdin ; stty echo
# perl -e 'use Term::ReadKey ; print STDERR "Password:\n" ; ReadMode "noecho" ; $_=<STDIN> ; ReadMode "normal" ; chomp $_ ; print crypt($_, "\$6\$16CHARACTERSSALT") . "\n"'
# ruby -e '["io/console","digest/sha2"].each {|i| require i} ; STDERR.puts "Password:" ; puts STDIN.noecho(&:gets).chomp.crypt("$6$16CHARACTERSSALT")'
# python -c 'import crypt,getpass ; print(crypt.crypt(getpass.getpass(), "$6$16CHARACTERSSALT"))'

# nc -l [-p] {port} > file ## nc -w3 {host} {port} < file  # netcat xfr
# ssh user@ipaddr "su -c 'sh -xs - arg1 argN'" < script.sh
# ssh user@ipaddr "sudo sh -xs - arg1 argN" < script.sh  # w/ sudo

## WITHOUT availability of netcat or ssh/scp on system:
##  (host) simple http server for files:
##         php -S localhost:{port} [-t {dir}]
##         ruby -r un -e httpd -- [-b localhost] -p {port} {dir}
##         python -m http.server {port} [-b 0.0.0.0] [-d {dir}]
##  (host) kill HTTP server process: kill -9 $(pgrep -f 'python -m http\.server')
##  (client) tools:
##    [curl | wget | aria2c | fetch | ftp] http://{host}:{port}/{path}/file

# usage: [env variant=oshost] sh vminstall_chroot.sh [oshost_machine [GUEST]]
#   (default) [variant=freebsd] sh vminstall_chroot.sh [freebsd_x86_64 [freebsd-x86_64-std]]

STORAGE_DIR=${STORAGE_DIR:-$(dirname $0)} ; PROVIDER=${PROVIDER:-libvirt}
ISOS_PARDIR=${ISOS_PARDIR:-/mnt/Data0/distros}
FIRMWARE_BHYVE_X64=${FIRMWARE_BHYVE_X64:-/usr/local/share/uefi-firmware/BHYVE_UEFI_CODE.fd}
FIRMWARE_QEMU_X64=${FIRMWARE_QEMU_X64:-/usr/share/OVMF/OVMF_CODE.fd}
FIRMWARE_QEMU_AA64=${FIRMWARE_QEMU_AA64:-/usr/share/AAVMF/AAVMF_CODE.fd}


_prep() {
  mkdir -p $HOME/.ssh/publish_krls $HOME/.pki/publish_crls
  cp -a $HOME/.ssh/publish_krls init/common/skel/_ssh/
  cp -a $HOME/.pki/publish_crls init/common/skel/_pki/

  OUT_DIR=${OUT_DIR:-build/${GUEST}}
  mkdir -p ${OUT_DIR}
  if [ "bhyve" = "${PROVIDER}" ] ; then
    truncate -s 30720M ${OUT_DIR}/${GUEST}.raw ;
  else
    qemu-img create -f qcow2 ${OUT_DIR}/${GUEST}.qcow2 30720M ;
  fi

  #if [ ! "${EXTRA_ARGS}" ] || [ ! "${EXTRA_ARGS}" = " " ] ; then
  #  ${PYTHON:-python3} -m http.server 8080 -d /tmp  &
  #  echo "[curl | wget | aria2c | fetch | ftp] http://{host}:{port}/{path}/file" ;
  #  sleep 5 ;
  #fi
}

_finish() {
  #if [ ! "${EXTRA_ARGS}" ] || [ ! "${EXTRA_ARGS}" = " " ] ; then
  #  echo "to kill HTTP server process: kill -9 \$(pgrep -f 'python -m http\.server')" ;
  #fi

  if command -v erb > /dev/null ; then
    erb variant=${variant} init/common/Vagrantfile_${PROVIDER}.erb \
      > ${OUT_DIR}/Vagrantfile ;
  elif command -v chevron > /dev/null ; then
    echo "{\"variant\":\"${variant}\"}" | chevron -d /dev/stdin \
      init/common/Vagrantfile_${PROVIDER}.mustache > ${OUT_DIR}/Vagrantfile ;
  elif command -v pystache > /dev/null ; then
    pystache init/common/Vagrantfile_${PROVIDER}.mustache \
      "{\"variant\":\"${variant}\"}" > ${OUT_DIR}/Vagrantfile ;
  elif command -v mustache > /dev/null ; then
    echo "{\"variant\":\"${variant}\"}" | mustache - init/common/Vagrantfile_${PROVIDER}.mustache > ${OUT_DIR}/Vagrantfile ;
  fi
  cp -a init/common/catalog.json* init/common/qemu_lxc/vmrun.sh ${OUT_DIR}/
  sleep 30
}

_install_x86_64() {
  if [ "bhyve" = "${PROVIDER}" ] ; then
    cp -a ${FIRMWARE_BHYVE_X64} init/common/qemu_lxc/vmrun_bhyve.args init/common/qemu_lxc/vmrun_qemu_x86_64.args ${OUT_DIR}/ ;
  else
    cp -a ${FIRMWARE_QEMU_X64} init/common/qemu_lxc/vmrun_bhyve.args init/common/qemu_lxc/vmrun_qemu_x86_64.args ${OUT_DIR}/ ;
  fi

  if [ "1" = "${USE_VIRTINST:-0}" ] ; then
    #-------------- using virtinst ------------------
    CONNECT_OPT=${CONNECT_OPT:---connect qemu:///system}
    VUEFI_OPTS=${VUEFI_OPTS:---boot uefi}

    # NOTE, to convert qemu-system args to libvirt domain XML:
    #  eval "echo \"$(< vminstall_qemu.args)\"" > /tmp/install_qemu.args
    #  virsh ${CONNECT_OPT} domxml-from-native qemu-argv /tmp/install_qemu.args

    virt-install ${CONNECT_OPT} --arch x86_64 --memory 2048 --vcpus 2 \
      --controller usb,model=ehci --controller virtio-serial \
      --console pty,target_type=virtio --graphics vnc,port=-1 \
      --network network=default,model=virtio-net,mac=RANDOM \
      --boot menu=on,cdrom,hd,network --controller scsi,model=virtio-scsi \
      --disk path=${OUT_DIR}/${GUEST}.qcow2,cache=writeback,discard=unmap,detect_zeroes=unmap,bus=scsi,format=qcow2 \
      --cdrom=${ISO_PATH} ${VUEFI_OPTS} -n ${GUEST} &

    sleep 30 ; virsh ${CONNECT_OPT} vncdisplay ${GUEST} ;
    #sleep 5 ; virsh ${CONNECT_OPT} dumpxml ${GUEST} > ${OUT_DIR}/${GUEST}.xml ;
  elif [ "$(uname -s)" = "FreeBSD" ] && [ "bhyve" = "${PROVIDER}" ] ; then
    #---------------- using bhyve -------------------
    printf "%40s\n" | tr ' ' '#'
    echo '### Warning: FreeBSD bhyve currently requires root/sudo permission ###'
    printf "%40s\n\n" | tr ' ' '#' ; sleep 5

    BUEFI_OPTS=${BUEFI_OPTS:- -s 29,fbuf,tcp=0.0.0.0:${VNCPORT:-5901},w=1024,h=768 \
      -l bootrom,${FIRMWARE_BHYVE_X64}}

    if [ "1" = "${FREEBSDGUEST:-0}" ] ; then
      #bhyveload -m 2048M -d ${OUT_DIR}/${GUEST}.raw ${GUEST} ;
      sleep 1 ;
    else
      cat << EOF > ${OUT_DIR}/device.map ;
(hd0) ${OUT_DIR}/${GUEST}.raw
(cd0) ${ISO_PATH}
EOF
      grub-bhyve -m ${OUT_DIR}/device.map -r cd0 -M 2048M ${GUEST} ;
    fi

    bhyve -A -H -P -c 2 -m 2048M -s 0,hostbridge -s 1,lpc \
      -s 2,virtio-net,${NET_OPT:-tap0},mac=52:54:00:$(openssl rand -hex 3 | sed 's|\(..\)|\1:|g; s|:$||') \
      -s 3,ahci-hd,${OUT_DIR}/${GUEST}.raw -l com1,stdio \
      ${BUEFI_OPTS} -s 31,ahci-cd,${ISO_PATH} ${GUEST} &

    vncviewer :${VNCPORT:-5901} &
  else
    #------------ using qemu-system-* ---------------
    QUEFI_OPTS=${QUEFI_OPTS:-"-smbios type=0,uefi=on -bios ${FIRMWARE_QEMU_X64}"}
    if [ "$(uname -s)" = "Linux" ] ; then
      echo "Verify bridge device allowed in /etc/qemu/bridge.conf" ; sleep 3 ;
      cat /etc/qemu/bridge.conf ; sleep 5 ;
    fi
    echo "(if needed) Quickly catch boot menu to add kernel boot parameters" ;
    sleep 5 ;

    qemu-system-x86_64 -machine q35,accel=kvm:hvf:tcg \
      -global PIIX4_PM.disable_s3=1 -global PIIX4_PM.disable_s4=1 \
      -smp cpus=2 -m size=2048 -boot order=cdn,menu=on -name ${GUEST} \
      -nic ${NET_OPT:-bridge,br=br0},id=net0,model=virtio-net-pci,mac=52:54:00:$(openssl rand -hex 3 | sed 's|\(..\)|\1:|g; s|:$||') \
      -device qemu-xhci,id=usb -usb -device usb-kbd -device usb-tablet \
      -device virtio-scsi-pci,id=scsi0 -device scsi-hd,drive=hd0 \
      -drive file=${OUT_DIR}/${GUEST}.qcow2,cache=writeback,discard=unmap,detect-zeroes=unmap,if=none,id=hd0,format=qcow2 \
      -display default,show-cursor=on -vga none -device qxl-vga,vgamem_mb=64 \
      ${QUEFI_OPTS} ${CDROM_OPT:--cdrom ${ISO_PATH}} -no-reboot &
    echo "### Once network connected, transfer needed file(s) ###" ;
  fi
  _finish
}

_install_aarch64() {
  cp -a ${FIRMWARE_QEMU_AA64} init/common/qemu_lxc/vmrun_qemu_aarch64.args ${OUT_DIR}/

  if [ "1" = "${USE_VIRTINST:-0}" ] ; then
    #-------------- using virtinst ------------------
    CONNECT_OPT=${CONNECT_OPT:---connect qemu:///system}
    VUEFI_OPTS=${VUEFI_OPTS:---boot uefi}

    # NOTE, to convert qemu-system args to libvirt domain XML:
    #  eval "echo \"$(< vminstall_qemu.args)\"" > /tmp/install_qemu.args
    #  virsh ${CONNECT_OPT} domxml-from-native qemu-argv /tmp/install_qemu.args

    virt-install ${CONNECT_OPT} --arch aarch64 --memory 2048 --vcpus 2 \
      --controller usb,model=ehci --controller virtio-serial \
      --console pty,target_type=virtio --graphics vnc,port=-1 \
      --network network=default,model=virtio-net,mac=RANDOM \
      --boot menu=on,cdrom,hd,network --controller scsi,model=virtio-scsi \
      --disk path=${OUT_DIR}/${GUEST}.qcow2,cache=writeback,discard=unmap,detect_zeroes=unmap,bus=scsi,format=qcow2 \
      --cdrom=${ISO_PATH} ${VUEFI_OPTS} -n ${GUEST} &

    sleep 30 ; virsh ${CONNECT_OPT} vncdisplay ${GUEST} ;
    #sleep 5 ; virsh ${CONNECT_OPT} dumpxml ${GUEST} > ${OUT_DIR}/${GUEST}.xml ;
  else
    #------------ using qemu-system-* ---------------
    QUEFI_OPTS=${QUEFI_OPTS:-"-smbios type=0,uefi=on -bios ${FIRMWARE_QEMU_AA64}"}
    if [ "$(uname -s)" = "Linux" ] ; then
      echo "Verify bridge device allowed in /etc/qemu/bridge.conf" ; sleep 3 ;
      cat /etc/qemu/bridge.conf ; sleep 5 ;
    fi
    echo "(if needed) Quickly catch boot menu to add kernel boot parameters" ;
    sleep 5 ;

    qemu-system-aarch64 -cpu cortex-a57 -machine virt,gic-version=3,acpi=off,accel=kvm:hvf:tcg \
      -smp cpus=2 -m size=2048 -boot order=cdn,menu=on -name ${GUEST} \
      -nic ${NET_OPT:-bridge,br=br0},id=net0,model=virtio-net-pci,mac=52:54:00:$(openssl rand -hex 3 | sed 's|\(..\)|\1:|g; s|:$||') \
      -device qemu-xhci,id=usb -usb -device usb-kbd -device usb-tablet \
      -device virtio-blk-pci,drive=hd0 \
      -drive file=${OUT_DIR}/${GUEST}.qcow2,cache=writeback,discard=unmap,detect-zeroes=unmap,if=none,id=hd0,format=qcow2 \
      -display default,show-cursor=on -vga none -device virtio-gpu-pci \
      ${QUEFI_OPTS} ${CDROM_OPT:--cdrom ${ISO_PATH}} -no-reboot &
    echo "### Once network connected, transfer needed file(s) ###" ;
  fi
  _finish
}
#----------------------------------------


## freebsd ##
  ##!! (chrootsh) navigate to single user: 2
  ##!! if late, Live CD -> root/-

  #mdmfs -s 100m md1 /mnt ; mdmfs -s 100m md2 /tmp ; cd /tmp
  #ifconfig ; dhclient -l /tmp/dhclient.leases -p /tmp/dhclient.lease.{ifdev} {ifdev}

  ## (FreeBSD) install via chroot
  ## NOTE, transfer [dir(s) | file(s)]: scripts.tar (init/common, init/freebsd, scripts/freebsd)

  #geom -t
  #sh init/common/gpart_setup_vmfreebsd.sh part_format [std | zfs]
  #sh init/common/gpart_setup_vmfreebsd.sh mount_filesystems [std | zfs]

  #sh init/freebsd/[std | zfs]-install.sh [hostname [$PASSWD_CRYPTED]]

freebsd_x86_64() {
  FREEBSDGUEST=1
  variant=${variant:-freebsd} ; GUEST=${1:-${variant}-x86_64-std}

  ISO_PATH=${ISO_PATH:-$(find ${ISOS_PARDIR}/freebsd -name 'FreeBSD-*-amd64-disc1.iso' | tail -n1)}
  (cd ${ISOS_PARDIR}/freebsd ; sha256sum --ignore-missing -c CHECKSUM.SHA256-FreeBSD-*-RELEASE-amd64)

  sleep 5 ; _prep ; sleep 3 ; _install_x86_64
}
freebsd_aarch64() {
  variant=${variant:-freebsd} ; GUEST=${1:-${variant}-aarch64-std}

  ISO_PATH=${ISO_PATH:-$(find ${ISOS_PARDIR}/freebsd -name 'FreeBSD-*-aarch64-disc1.iso' | tail -n1)}
  (cd ${ISOS_PARDIR}/freebsd ; sha256sum --ignore-missing -c CHECKSUM.SHA256-FreeBSD-*-RELEASE*-aarch64)

  sleep 5 ; _prep ; sleep 3 ; _install_aarch64
}
#----------------------------------------

## debian ##
  ##append to boot parameters: 3 text textmode=1

  ##!! (debian) login user/passwd: user/live
  ##!! (devuan) login user/passwd: devuan/devuan

  #sudo su ; . /etc/os-release
  #ip link ; [networkctl status ; networkctl up {ifdev}]
  #[dhcpcd {ifdev} ; dhclient {ifdev}]
  #systemctl stop ssh ; invoke-rc.d ssh stop
  #mount -o remount,size=1G /run/live/overlay ; df -h ; sleep 5
  #sed -i '/main.*$/ s|main.*$|main contrib non-free|' /etc/apt/sources.list
  #apt-get --yes update --allow-releaseinfo-change
  #apt-get --yes install gdisk [lvm2 btrfs-progs] [dnf zypper]

  #------------ if using ZFS ---------------
  #apt-get --yes install --no-install-recommends linux-headers-$(uname -r)

  #sed -i 's|^#deb|deb|g' /etc/apt/sources.list
  #apt-get --yes update --allow-releaseinfo-change
  #apt-get --yes install -t ${VERSION_CODENAME/ */}-backports --no-install-recommends zfs-dkms
  #apt-get --yes install -t ${VERSION_CODENAME/ */}-backports --no-install-recommends zfsutils-linux

  #modprobe zfs ; zfs version ; sleep 5
  #-----------------------------------------

debian_x86_64() {
  variant=${variant:-debian} ; service_mgr=${service_mgr:-sysvinit}
  GUEST=${1:-${variant}-x86_64-std}
  #ISO_PATH=${ISO_PATH:-$(find ${ISOS_PARDIR}/debian/live -name 'debian-live-*-amd64*.iso' | tail -n1)}
  #(cd ${ISOS_PARDIR}/debian/live ; sha256sum --ignore-missing -c SHA256SUMS)
  ISO_PATH=${ISO_PATH:-$(find ${ISOS_PARDIR}/devuan/live -name 'devuan_*_amd64_minimal-live.iso' | tail -n1)}
  (cd ${ISOS_PARDIR}/devuan/live ; sha256sum --ignore-missing -c SHA256SUMS.txt)

  sleep 5 ; _prep ; sleep 3 ; _install_x86_64
}
#----------------------------------------

## void ##
  ##!! login user/passwd: anon/voidlinux

  #ip link ; [dhcpcd {ifdev}]
  #[bash;] sv down sshd ; export MIRRORHOST=mirror.clarkson.edu/voidlinux
  #yes | xbps-install -Sy -R http://${MIRRORHOST}/current -u xbps ; sleep 3
  #yes | xbps-install -Sy -R http://${MIRRORHOST}/current netcat wget parted gptfdisk libffi gnupg2 curl [lvm2 btrfs-progs] [apk-tools debootstrap pacman]

  #------------ if using ZFS ---------------
  ## install zfs, if needed ##
  ##yes | xbps-install -Sy [linux-headers] zfs
  ##mkdir -p /etc/dkms ; echo REMAKE_INITRD=yes > /etc/dkms/zfs.conf

  #modprobe zfs ; zfs version ; sleep 5
  #-----------------------------------------

void_x86_64() {
  variant=${variant:-void} ; GUEST=${1:-${variant}-x86_64-std}
  #ISO_PATH=${ISO_PATH:-$(find ${ISOS_PARDIR}/voidlinux -name 'void-live-x86_64-*.iso' | tail -n1)}
  #ISO_PATH=${ISO_PATH:-$(find ${ISOS_PARDIR}/voidlinux -name 'hrmpf-x86_64-*.iso' | tail -n1)}
  ISO_PATH=${ISO_PATH:-$(find ${ISOS_PARDIR}/voidlinux -name 'void-rescue-x86_64-*.iso' | tail -n1)}
  (cd ${ISOS_PARDIR}/voidlinux ; sha256sum --ignore-missing -c sha256sum.txt)

  sleep 5 ; _prep ; sleep 3 ; _install_x86_64
}
#----------------------------------------

## archlinux ##
  ##!! (arch) login user/passwd: -/-
  ##!! (artix) login user/passwd: artix/artix
  ##!! (archlinuxarm) login user/passwd: alarm/alarm
  ##!! (armtix) login user/passwd: armtix/armtix

  #sudo su
  # ip link ; [networkctl status ; networkctl up {ifdev}]
  #[dhcpcd {ifdev}]
  #sed -i 's|\(^SigLevel.*\)|#\1\nSigLevel = Never|' /etc/pacman.conf
  #(arch) mount -o remount,size=1G /run/archiso/cowspace ; df -h ; sleep 5
  #(arch) pacman-key --init ; pacman -Sy archlinux-keyring
  #(arch) pacman-key --populate archlinux
  #(artix) mount -o remount,size=1G /run/artix/cowspace ; df -h ; sleep 5
  #(artix) pacman-key --init ; pacman -Sy artix-keyring
  #(artix) pacman-key --populate artix
  #(arch|artix) sed -i 's|^#\(SigLevel.*\)|\1| ; s|^\(SigLevel = Never\)|#\1|' /etc/pacman.conf
  ## NOTE, transfer archzfs config file: init/archlinux/repo_archzfs.cfg
  #cat init/archlinux/repo_archzfs.cfg >> /etc/pacman.conf
  #curl -o /tmp/archzfs.gpg http://archzfs.com/archzfs.gpg
  #pacman-key --add /tmp/archzfs.gpg ; pacman-key --lsign-key F75D9D76
  #(artix) pacman -Sy --needed gnu-netcat parted dosfstools gptfdisk [lvm2 btrfs-progs]
  #[pacman -Sy debootstrap]

  #------------ if using ZFS ---------------
  #pacman -Sy --needed linux-headers zfs-dkms zfs-utils
  ##--- (arch) or retrieve archived zfs-linux package instead of zfs-dkms ---
  ## Note, xfer archived zfs-linux package matching kernel (uname -r)
  ## example kernelver -> 5.7.11-arch1-1 becomes 5.7.11.arch1.1-1
  ## curl -o /tmp/zfs-linux.pkg.tar.zst 'http://mirror.sum7.eu/archlinux/archzfs/archive_archzfs/zfs-linux-<ver>_<kernelver>-x86_64.pkg.tar.zst'
  ## pacman -U /tmp/zfs-linux.pkg.tar.zst
  ##--- (arch)

  #modprobe zfs ; zfs version ; sleep 5
  #-----------------------------------------

archlinux_x86_64() {
  variant=${variant:-archlinux} ; service_mgr=${service_mgr:-runit}
  GUEST=${1:-${variant}-x86_64-std}
  #ISO_PATH=${ISO_PATH:-$(find ${ISOS_PARDIR}/archlinux -name 'archlinux-*.iso' | tail -n1)}
  #(cd ${ISOS_PARDIR}/archlinux ; sha1sum --ignore-missing -c sha1sums.txt)
  #ISO_PATH=${ISO_PATH:-$(find ${ISOS_PARDIR}/artix -name 'artix-base-runit-*.iso' | tail -n1)}
  ISO_PATH=${ISO_PATH:-$(find ${ISOS_PARDIR}/artix -name 'artix-rescue-runit-*.iso' | tail -n1)}
  (cd ${ISOS_PARDIR}/artix ; sha256sum --ignore-missing -c sha256sums)

  sleep 5 ; _prep ; sleep 3 ; _install_x86_64
}
#----------------------------------------

## alpine ##
  ##!! login user/passwd: root/-

  #ifconfig ; ifconfig {ifdev} up ; udhcpc -i {ifdev} ; cd /tmp

  #service sshd stop ; date +%Y.%m.%d-%H:%M -s "YYYY.mm.dd-23:59"
  #. /etc/os-release ; export MIRRORHOST=dl-cdn.alpinelinux.org/alpine
  #echo http://${MIRRORHOST}/v$(cat /etc/alpine-release | cut -d. -f1-2)/main >> /etc/apk/repositories
  #echo http://${MIRRORHOST}/v$(cat /etc/alpine-release | cut -d. -f1-2)/community >> /etc/apk/repositories
  #apk update
  #apk add e2fsprogs xfsprogs dosfstools sgdisk libffi gnupg curl util-linux multipath-tools perl [lvm2 btrfs-progs] [debootstrap pacman]
  #setup-devd udev

  #------------ if using ZFS ---------------
  #apk add zfs

  #modprobe zfs ; zfs version ; sleep 5
  #-----------------------------------------

alpine_x86_64() {
  variant=${variant:-alpine} ; GUEST=${1:-${variant}-x86_64-std}

   ISO_PATH=${ISO_PATH:-$(find ${ISOS_PARDIR}/alpine -name "alpine-extended-*-x86_64.iso" | tail -n1)}
  (cd ${ISOS_PARDIR}/alpine ; sha256sum --ignore-missing -c alpine-extended-*-x86_64.iso.sha256)

  sleep 5 ; _prep ; sleep 3 ; _install_x86_64
}
alpine_aarch64() {
  variant=${variant:-alpine} ; GUEST=${1:-${variant}-aarch64-std}

  ISO_PATH=${ISO_PATH:-$(find ${ISOS_PARDIR}/alpine -name "alpine-standard-*-aarch64.iso" | tail -n1)}
  (cd ${ISOS_PARDIR}/alpine ; sha256sum --ignore-missing -c alpine-standard-*-aarch64.iso.sha256)

  sleep 5 ; _prep ; sleep 3 ; _install_aarch64
}
#----------------------------------------

## suse ##
  ##append to boot parameters: 3 text textmode=1

  ##!! login user/passwd: linux/-

  #sudo su ; . /etc/os-release ; export MIRRORHOST=download.opensuse.org
  #networkctl status ; networkctl up {ifdev}
  #nmcli device status ; nmcli connection up {ifdev}
  #wicked ifstatus all ; wicked ifup {ifdev}
  #zypper --non-interactive refresh

  #zypper install ca-certificates-cacert ca-certificates-mozilla gptfdisk efibootmgr [lvm2 btrfsprogs] [debootstrap dnf dnf-plugins-core]
  #zypper --gpg-auto-import-keys refresh
  #update-ca-certificates

  #------------ if using ZFS ---------------
  #zypper --non-interactive install dkms kernel-devel
  #zypper --gpg-auto-import-keys addrepo http://${MIRRORHOST}/repositories/filesystems/${VERSION_ID}/filesystems.repo
  #zypper --gpg-auto-import-keys refresh
  #zypper --non-interactive install zfs zfs-kmp-default

  #modprobe zfs ; zfs version ; sleep 5
  #-----------------------------------------

suse_x86_64() {
  variant=${variant:-suse} ; GUEST=${1:-${variant}-x86_64-std}

  #ISO_PATH=${ISO_PATH:-$(find ${ISOS_PARDIR}/opensuse/live -name "openSUSE-Leap-*-Live-x86_64*.iso" | tail -n1)}
  ISO_PATH=${ISO_PATH:-$(find ${ISOS_PARDIR}/opensuse/live -name "GeckoLinux_*.x86_64*.iso" | tail -n1)}
  #(cd ${ISOS_PARDIR}/opensuse/live ; sha256sum --ignore-missing -c openSUSE-Leap-*-Live-x86_64*.iso.sha256)
  (cd ${ISOS_PARDIR}/opensuse/live ; sha256sum --ignore-missing -c GeckoLinux_*.x86_64*.iso.sha256)

  sleep 5 ; _prep ; sleep 3 ; _install_x86_64
}
suse_aarch64() {
  variant=${variant:-suse} ; GUEST=${1:-${variant}-aarch64-std}

  ISO_PATH=${ISO_PATH:-$(find ${ISOS_PARDIR}/opensuse/live/aarch64 -name "openSUSE-Leap-*-Live-aarch64*.iso" | tail -n1)}
  (cd ${ISOS_PARDIR}/opensuse/live/aarch64 ; sha256sum --ignore-missing -c openSUSE-Leap-*-Live-aarch64*.iso.sha256)

  sleep 5 ; _prep ; sleep 3 ; _install_aarch64
}
#----------------------------------------

##redhat ##
  ##!! login user/passwd: liveuser/-

  #. /etc/os-release ; export MIRRORHOST=dl.rockylinux.org/pub/rocky
  #networkctl status ; networkctl up {ifdev}
  #nmcli device status ; nmcli connection up {ifdev}
  #[dnf | yum] -y check-update ; setenforce 0 ; sestatus ; sleep 5
  #[dnf | yum] -y install nmap-ncat [lvm2] [debootstrap]

  #------------ if using ZFS ---------------
  #[dnf | yum] -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-[9 | 7].noarch.rpm
  #[dnf | yum] -y install kernel kernel-devel
  #. /etc/os-release ; echo ${VERSION_ID}
  #kver=$(dnf list --installed kernel | sed -n 's|kernel[a-z0-9._]*[ ]*\([^ ]*\)[ ]*.*$|\1|p' | tail -n1)
  ##(-stream) ZFS_REL=`echo $kver | sed 's|.*\.el\(.*\)$|\1|'` ; echo $ZFS_REL
  #[dnf | yum] -y install http://download.zfsonlinux.org/epel/zfs-release.el${ZFS_REL:-${VERSION_ID/./_}}.noarch.rpm
  #rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-zfsonlinux
  #dnf config-manager --disable zfs ; dnf config-manager --enable zfs-kmod
  #[dnf | yum] -y install zfs
  #echo REMAKE_INITRD=yes > /etc/dkms/zfs.conf

  #dkms status ; modprobe zfs ; zfs version ; sleep 5
  #dnf config-manager --disable zfs-kmod ; dnf config-manager --enable zfs
  #-----------------------------------------

redhat_x86_64() {
  RELEASE=${RELEASE:-9} ; variant=${variant:-redhat}
  GUEST=${1:-${variant}-x86_64-std}
  ISO_PATH=${ISO_PATH:-$(find ${ISOS_PARDIR}/rocky/live -name 'Rocky-*.iso' | tail -n1)}
  (cd ${ISOS_PARDIR}/rocky/live ; sha256sum --ignore-missing -c CHECKSUM)

  sleep 5 ; _prep ; sleep 3 ; _install_x86_64
}
#redhat_aarch64() {
#  RELEASE=${RELEASE:-9} ; variant=${variant:-redhat}
#  GUEST=${1:-${variant}-aarch64-std}
#  ISO_PATH=${ISO_PATH:-$(find ${ISOS_PARDIR}/rocky/live/aarch64 -name 'Rocky-*-aarch64-*.iso' | tail -n1)}
#  (cd ${ISOS_PARDIR}/rocky/live/aarch64 ; sha256sum --ignore-missing -c CHECKSUM)
#
#  sleep 5 ; _prep ; sleep 3 ; _install_aarch64
#}
#----------------------------------------

## mageia ##
  ##append to boot parameters: 3 text textmode=1

  ##!! login user/passwd: live/-

  #su - ; export MIRRORHOST=mirrors.kernel.org/mageia
  #networkctl status ; networkctl up {ifdev}
  #nmcli device status ; nmcli connection up {ifdev}
  #dnf -y check-update ; [dnf -y install lvm2 btrfs-progs ;] sleep 5

mageia_x86_64() {
  variant=${variant:-mageia} ; GUEST=${1:-${variant}-x86_64-std}
  ISO_PATH=${ISO_PATH:-$(find ${ISOS_PARDIR}/mageia/live -name 'Mageia-*-Live-*-x86_64.iso' | tail -n1)}
  (cd ${ISOS_PARDIR}/mageia/live ; sha512sum --ignore-missing -c Mageia-*-Live-*-x86_64.iso.sha512)
  sleep 5 ; _prep ; sleep 3 ; _install_x86_64
}
#----------------------------------------

## pclinuxos ##
  # (PCLinuxOS distro) install using draklive-install, then post chroot cmds
  ##!! login user/passwd: guest/-
  ## NOTE, transfer [dir(s) | file(s)]: scripts.tar (init/common, init/pclinuxos, scripts/pclinuxos)

  #su - ; export MIRRORHOST=spout.ussg.indiana.edu/linux/pclinuxos
  #nmcli device status ; nmcli connection up {ifdev}
  #sed -i 's|^[ ]*rpm|# rpm|' /etc/apt/sources.list
  #sed -i "/${MIRRORHOST}/ s|^.*rpm|rpm|" /etc/apt/sources.list
  #apt-get -y update ; sleep 5
  #apt-get -y install netcat gdisk efibootmgr [lvm2 btrfs-progs]
  #apt-get -y --fix-broken install

  #[[sgdisk -p | sfdisk -l] /dev/[sv]da | parted /dev/[sv]da -s unit GiB print]
  #mkdir -p /mnt
  #[MKFS_CMD=mkfs.ext4] sh init/common/disk_setup_vmlinux.sh part_format [sgdisk | sfdisk | parted] [std | lvm | btrfs] [ .. ]

  ## (btrfs) After partitioning (by hand or script), USE Custom partitioning in
  ## draklive-install with Mount options advanced for / (root): subvol=@
  #draklive-install --expert --noauto
  #sh init/pclinuxos/[std | lvm | btrfs]-post_drakliveinstall.sh [hostname [$PASSWD_PLAIN]]

pclinuxos_x86_64() {
  variant=${variant:-pclinuxos} ; GUEST=${1:-${variant}-x86_64-std}
  ISO_PATH=${ISO_PATH:-$(find ${ISOS_PARDIR}/pclinuxos -name 'pclinuxos64-*.iso' | tail -n1)}
  (cd ${ISOS_PARDIR}/pclinuxos ; md5sum --ignore-missing -c pclinuxos64-*.md5sum)

  sleep 5 ; _prep ; sleep 3 ; _install_x86_64
}
#----------------------------------------

## netbsd ##
  # ?? QEMU x86_64 boot uefi kernel page fault for iso (need : -machine pc,accel=kvm)
  # add options: -global PIIX4_PM.disable_s3=1 -global PIIX4_PM.disable_s4=1

  ##!! (chrootsh) navigate thru installer to shell: 1 ; a ; a ; e ; a

  #ksh
  #mount_mfs -s 100m md1 /tmp ; cd /tmp
  #ifconfig ; dhcpcd {ifdev}

  ## (NetBSD) install via chroot
  ## NOTE, transfer [dir(s) | file(s)]: scripts.tar (init/common, init/netbsd, scripts/netbsd)

  #gpt show -l sd0
  #sh init/netbsd/gpt_setup_vmnetbsd.sh part_format [std]
  #sh init/netbsd/gpt_setup_vmnetbsd.sh mount_filesystems [std]

  #sh init/netbsd/std-install.sh [hostname [$PASSWD_PLAIN]]

netbsd_x86_64() {
  variant=${variant:-netbsd} ; GUEST=${1:-${variant}-x86_64-std}

  ISO_PATH=${ISO_PATH:-$(find ${ISOS_PARDIR}/netbsd -name 'NetBSD-*-amd64.iso' | tail -n1)}
  (cd ${ISOS_PARDIR}/netbsd ; sha512sum --ignore-missing -c SHA512) ; sleep 5

  sleep 5 ; _prep ; sleep 3 ; _install_x86_64
}
netbsd_aarch64() {
  variant=${variant:-netbsd} ; GUEST=${1:-${variant}-aarch64-std}

  ISO_PATH=${ISO_PATH:-$(find ${ISOS_PARDIR}/netbsd -name 'NetBSD-*-aarch64.iso' | tail -n1)}
  (cd ${ISOS_PARDIR}/netbsd ; sha512sum --ignore-missing -c SHA512)

  sleep 5 ; _prep ; sleep 3 ; _install_aarch64
}
#----------------------------------------

## openbsd ##
  ##!! login user/passwd: root/-
  ##!! (chrootsh) enter shell: S

  ##mount -t mfs -s 100m md1 /tmp ; cd /tmp [; mount -t mfs -s 100m md2 /mnt]
  #mount_mfs -s 100m md1 /tmp ; cd /tmp [; mount_mfs -s 100m md2 /mnt]
  #ifconfig ; dhclient -L /tmp/dhclient.lease.{ifdev} {ifdev}

  ## (OpenBSD) install via chroot
  ## NOTE, transfer [dir(s) | file(s)]: scripts.tar (init/common, init/openbsd, scripts/openbsd)

  #fdisk sd0
  #sh init/openbsd/disklabel_setup_vmopenbsd.sh part_format
  #sh init/openbsd/disklabel_setup_vmopenbsd.sh mount_filesystems

  #sh init/openbsd/std-install.sh [hostname [$PASSWD_PLAIN]]

openbsd_x86_64() {
  variant=${variant:-openbsd} ; GUEST=${1:-${variant}-x86_64-std}

  ## ?? boot uefi NOT WORKING for iso ??
  #QUEFI_OPTS=" "
  #VUEFI_OPTS=" "

  ISO_PATH=${ISO_PATH:-$(find ${ISOS_PARDIR}/openbsd/amd64 -name 'install*.img' | tail -n1)}
  (cd ${ISOS_PARDIR}/openbsd/amd64 ; sha256sum --ignore-missing -c SHA256)

  sleep 5 ; _prep
  qemu-img convert -O qcow2 ${ISO_PATH} ${OUT_DIR}/${GUEST}.qcow2
  qemu-img resize -f qcow2 ${OUT_DIR}/${GUEST}.qcow2 30720M
  sleep 3 ; _install_x86_64
}
openbsd_aarch64() {
  CDROM_OPT=${CDROM_OPT:-" "}
  variant=${variant:-openbsd} ; GUEST=${1:-${variant}-aarch64-std}

  ISO_PATH=${ISO_PATH:-$(find ${ISOS_PARDIR}/openbsd/arm64 -name 'install*.img' | tail -n1)}
  (cd ${ISOS_PARDIR}/openbsd/arm64 ; sha256sum --ignore-missing -c SHA256)

  sleep 5 ; _prep
  qemu-img convert -O qcow2 ${ISO_PATH} ${OUT_DIR}/${GUEST}.qcow2
  qemu-img resize -f qcow2 ${OUT_DIR}/${GUEST}.qcow2 30720M
  sleep 3 ; _install_aarch64
}

#----------------------------------------
${@:-freebsd_x86_64 freebsd-x86_64-std}


#-----------------------------------------
## package manager/bootstrap tools & config to install from existing Linux

#variant debian - distros(debian, devuan):
  # (devuan x86_64 MIRROR: deb.devuan.org/merged, service_mgr: sysvinit)
  # (devuan aarch64 MIRROR: pkgmaster.devuan.org/devuan, service_mgr: sysvinit)
  # (debian [x86_64|aarch64] MIRROR: deb.debian.org/debian)
  #  package(s): [perl,] debootstrap

#variant void: ([x86_64|aarch64] MIRROR: mirror.clarkson.edu/voidlinux)
  ## dnld: http://${MIRROR}/static/xbps-static-latest.<machine>-musl.tar.xz
  #  package(s): xbps[-install.static]

#variant archlinux: distros(x86_64: arch, artix [service_mgr: runit]):
  #  package(s): libffi, curl, pacman

#variant alpine: ([x86_64|aarch64] MIRROR: dl-cdn.alpinelinux.org/alpine)
  ## dnld: http://${MIRROR}/latest-stable/main/<machine>/apk-tools-static-*.apk
  #  package(s): apk[-tools][.static] (download apk[-tools][-static])

#variant suse - distros(opensuse): ([x86_64,aarch64] MIRROR: download.opensuse.org)
  #  package(s): zypper, rpm, ? rinse

#variant redhat - distros(rocky, almalinux, centos[-stream]):
  # (rocky [x86_64|aarch64] MIRROR: dl.rockylinux.org/pub/rocky)
  # (almalinux [x86_64|aarch64] MIRROR: repo.almalinux.org/almalinux)
  # (centos[-stream] [x86_64|aarch64] MIRROR: mirror.centos.org/centos)
  #  package(s): [dnf, dnf-plugins-core | yum, yum-utils], rpm, ? rinse

#variant mageia: ([x86_64,aarch64] MIRROR: mirrors.kernel.org/mageia)
  #  package(s): [dnf, dnf-plugins-core | yum, yum-utils], rpm

#variant pclinuxos: (x86_64 MIRROR: spout.ussg.indiana.edu/linux/pclinuxos)
  #  package(s): ?

#----------------------------------------
## (Linux distro) install via chroot
## NOTE, transfer [dir(s) | file(s)]: scripts.tar (init/common, init/<variant>, scripts/<variant>)

#  [[sgdisk -p | sfdisk -l] /dev/[sv]da | parted /dev/[sv]da -s unit GiB print]
#  [MKFS_CMD=mkfs.ext4] sh init/common/disk_setup_vmlinux.sh part_format [sgdisk | sfdisk | parted] [std | lvm | btrfs | zfs] [ .. ]
#  sh init/common/disk_setup_vmlinux.sh mount_filesystems [std | lvm | btrfs | zfs] [ .. ]

#  sh init/<variant>/[std | lvm | btrfs | zfs]-install.sh [hostname [$PASSWD_CRYPTED]]
#----------------------------------------
