#!/bin/sh -x

# passwd crypted hash: [md5|sha256|sha512] - [$1|$5|$6]$...
# perl -e 'use Term::ReadKey ; print "Password:\n" ; ReadMode "noecho" ; $_=<STDIN> ; ReadMode "normal" ; chomp $_ ; print crypt($_, "\$6\$16CHARACTERSSALT") . "\n"'
# ruby -e "['io/console','digest/sha2'].each {|i| require i} ; puts 'Password:' ; puts STDIN.noecho(&:gets).chomp.crypt(\"\$6\$16CHARACTERSSALT\")"
# python -c "import crypt,getpass ; print(crypt.crypt(getpass.getpass(), \"\$6\$16CHARACTERSSALT\"))"

# nc -l [-p] {port} > file ## nc -w3 {host} {port} < file  # netcat xfr
# ssh user@ipaddr "su -c 'sh -xs - arg1 argN'" < script.sh
# ssh user@ipaddr "sudo sh -xs - arg1 argN" < script.sh  # w/ sudo

## WITHOUT availability of netcat or ssh/scp on system:
##  (host) simple http server for files: python -m http.server {port}
##  (client) tools:
##    [curl | wget | aria2c | fetch | ftp] http://{host}:{port}/{path}/file

# usage: sh vminstall_chroot.sh [oshost [GUEST]]
#   (default) sh vminstall_chroot.sh [freebsd [freebsd-Release-zfs]]

USE_VIRTINST=${USE_VIRTINST:-0} ; STORAGE_DIR=${STORAGE_DIR:-$(dirname $0)}
ISOS_PARDIR=${ISOS_PARDIR:-/mnt/Data0/distros}

mkdir -p $HOME/.ssh/publish_krls $HOME/.pki/publish_crls
cp -R $HOME/.ssh/publish_krls init/common/skel/_ssh/
cp -R $HOME/.pki/publish_crls init/common/skel/_pki/

freebsd() {
  variant=${variant:-freebsd} ; GUEST=${1:-freebsd-Release-zfs}
  ISO_PATH=${ISO_PATH:-$(find ${ISOS_PARDIR}/freebsd -name 'FreeBSD-*-amd64-disc1.iso' | tail -n1)}
  (cd ${ISOS_PARDIR}/freebsd ; sha256sum --ignore-missing -c CHECKSUM.SHA256-FreeBSD-*-RELEASE-amd64)
  sleep 5

  ##!! (chrootsh) navigate to single user: 2
  ##!! if late, Live CD -> root/-

  #mdmfs -s 100m md1 /tmp ; mdmfs -s 100m md2 /mnt ; cd /tmp ; ifconfig
  #dhclient -l /tmp/dhclient.leases -p /tmp/dhclient.lease.{ifdev} {ifdev}

  ## (FreeBSD) install via chroot
  ## NOTE, transfer [dir(s) | file(s)]: init/common, init/freebsd

  #geom -t
  #sh init/common/gpart_setup_vmfreebsd.sh part_format_vmdisk [std | zfs]
  #sh init/common/gpart_setup_vmfreebsd.sh mount_filesystems

  #sh init/freebsd/zfs-install.sh [hostname [$CRYPTED_PASSWD]]
}

debian() {
  variant=${variant:-debian} ; GUEST=${1:-devuan-Stable-lvm}
  #ISO_PATH=${ISO_PATH:-$(find ${ISOS_PARDIR}/debian/live -name 'debian-live-*-amd64*.iso' | tail -n1)}
  #(cd ${ISOS_PARDIR}/debian/live ; sha256sum --ignore-missing -c SHA256SUMS)
  ISO_PATH=${ISO_PATH:-$(find ${ISOS_PARDIR}/devuan/live -name 'devuan_*_amd64_desktop-live.iso' | tail -n1)}
  (cd ${ISOS_PARDIR}/devuan/live ; sha256sum --ignore-missing -c SHA256SUMS.txt)
  sleep 5

  ##!! (debian) login user/passwd: user/live
  ##!! (devuan) login user/passwd: devuan/devuan

  #sudo su ; . /etc/os-release
  #export MIRRORHOST=[deb.devuan.org/merged | deb.debian.org/debian]
  #mount -o remount,size=1G /run/live/overlay ; df -h ; sleep 5
  #apt-get --yes update --allow-releaseinfo-change
  #apt-get --yes install gdisk [lvm2]

  #------------ if using ZFS ---------------
  #apt-get --yes install --no-install-recommends linux-headers-$(uname -r)

  #echo "deb http://$MIRRORHOST $VERSION_CODENAME-backports main" >> /etc/apt/sources.list
  #sed -i '/main.*$/ s|main.*$|main contrib non-free|' /etc/apt/sources.list
  #apt-get --yes update
  #apt-get --yes install -t $VERSION_CODENAME-backports --no-install-recommends zfs-dkms zfsutils-linux

  #modprobe zfs ; zpool version ; sleep 5
  #-----------------------------------------
}

void() {
  variant=${variant:-void} ; GUEST=${1:-voidlinux-Rolling-lvm}
  #ISO_PATH=${ISO_PATH:-$(find ${ISOS_PARDIR}/voidlinux -name 'void-live-x86_64-*.iso' | tail -n1)}
  #(cd ${ISOS_PARDIR}/voidlinux ; sha256sum --ignore-missing -c sha256.txt)
  #sleep 5
  ## change for ZFS already on iso
  ISO_PATH=${ISO_PATH:-$(find ${ISOS_PARDIR}/voidlinux -name 'Trident-*-x86_64.iso' | tail -n1)}
  (cd ${ISOS_PARDIR}/voidlinux ; sha256sum --ignore-missing -c Trident-*-x86_64.iso.sha256)
  sleep 5

  ##!! login user/passwd: anon/voidlinux

  #[bash;] sv down sshd ; export MIRRORHOST=mirror.clarkson.edu/voidlinux
  #yes | xbps-install -Sy -R http://${MIRRORHOST}/current -u xbps ; sleep 3
  #yes | xbps-install -Sy -R http://${MIRRORHOST}/current netcat wget parted gptfdisk libffi gnupg2 [lvm2]
  #cp /sbin/gpg2 /sbin/gpg

  #------------ if using ZFS ---------------
  #modprobe zfs ; zpool version ; sleep 5
  #-----------------------------------------
}

archlinux() {
  variant=${variant:-archlinux} ; GUEST=${1:-artix-Rolling-lvm}
  #ISO_PATH=${ISO_PATH:-$(find ${ISOS_PARDIR}/archlinux -name 'archlinux-*.iso' | tail -n1)}
  #(cd ${ISOS_PARDIR}/archlinux ; sha1sum --ignore-missing -c sha1sums.txt)
  ISO_PATH=${ISO_PATH:-$(find ${ISOS_PARDIR}/artix -name 'artix-*-openrc-*.iso' | tail -n1)}
  (cd ${ISOS_PARDIR}/artix ; sha256sum --ignore-missing -c sha256sums)
  sleep 5

  ##!! (arch) login user/passwd: -/-
  ##!! (artix) login user/passwd: artix/artix

  #sudo su
  #(arch) mount -o remount,size=1G /run/archiso/cowspace ; df -h ; sleep 5
  #(arch) pacman-key --init ; pacman-key --populate archlinux
  #(arch) pacman -Sy archlinux-keyring
  #(artix) mount -o remount,size=1G /run/artix/cowspace ; df -h ; sleep 5
  #(artix) pacman-key --init ; pacman-key --populate artix
  #(artix) pacman -Sy artix-keyring gnu-netcat parted dosfstools gptfdisk [lvm2]
  #pacman -Sy

  #------------ if using ZFS ---------------
  ## NOTE, transfer archzfs config file: init/archlinux/repo_archzfs.cfg
  #cat init/archlinux/repo_archzfs.cfg >> /etc/pacman.conf
  #curl -o /tmp/archzfs.gpg http://archzfs.com/archzfs.gpg
  #pacman-key --add /tmp/archzfs.gpg ; pacman-key --lsign-key F75D9D76

  #pacman -Sy zfs-dkms ; pacman -Sy --needed zfs-utils
  ##--- (arch) or retrieve archived zfs-linux package instead of zfs-dkms ---
  ## Note, xfer archived zfs-linux package matching kernel (uname -r)
  ## example kernelver -> 5.7.11-arch1-1 becomes 5.7.11.arch1.1-1
  ## curl -o /tmp/zfs-linux.pkg.tar.zst 'http://mirror.sum7.eu/archlinux/archzfs/archive_archzfs/zfs-linux-<ver>_<kernelver>-x86_64.pkg.tar.zst'
  ## pacman -U /tmp/zfs-linux.pkg.tar.zst
  ##--- (arch)

  #modprobe zfs ; zpool version ; sleep 5
  #-----------------------------------------
}

alpine() {
  variant=${variant:-alpine} ; GUEST=${1:-alpine-Stable-lvm}
  ISO_PATH=${ISO_PATH:-$(find ${ISOS_PARDIR}/alpine -name 'alpine-extended-*-x86_64.iso' | tail -n1)}
  (cd ${ISOS_PARDIR}/alpine ; sha256sum --ignore-missing -c alpine-extended-*-x86_64.iso.sha256)
  sleep 5

  ##!! login user/passwd: root/-

  #ifconfig ; ifconfig {ifdev} up ; udhcpc -i {ifdev} ; cd /tmp

  #service sshd stop
  #. /etc/os-release ; export MIRRORHOST=dl-cdn.alpinelinux.org/alpine
  #echo http://${MIRRORHOST}/v$(cat /etc/alpine-release | cut -d. -f1-2)/main >> /etc/apk/repositories
  #apk update
  #apk add e2fsprogs dosfstools sgdisk util-linux multipath-tools [lvm2]
  #setup-udev

  #------------ if using ZFS ---------------
  #apk add zfs

  #modprobe zfs ; zpool version ; sleep 5
  #-----------------------------------------
}

suse() {
  variant=${variant:-suse} ; GUEST=${1:-opensuse-Stable-lvm}
  ISO_PATH=${ISO_PATH:-$(find ${ISOS_PARDIR}/opensuse/live -name 'openSUSE-Leap-*-Live-x86_64-*.iso' | tail -n1)}
  (cd ${ISOS_PARDIR}/opensuse/live ; sha256sum --ignore-missing -c openSUSE-Leap-*-Live-x86_64-*.iso.sha256)
  sleep 5

  ##!! login user/passwd: linux/-

  #sudo su ; . /etc/os-release ; export MIRRORHOST=download.opensuse.org
  #zypper --non-interactive refresh

  #zypper install ca-certificates-cacert ca-certificates-mozilla efibootmgr [lvm2]
  #zypper --gpg-auto-import-keys refresh
  #update-ca-certificates

  #------------ if using ZFS ---------------
  #zypper --non-interactive install gptfdisk dkms kernel-devel
  #zypper --gpg-auto-import-keys addrepo http://${MIRRORHOST}/repositories/filesystems/$(echo ${PRETTY_NAME} | tr ' ' _)/filesystems.repo
  #zypper --gpg-auto-import-keys refresh
  #zypper --non-interactive install zfs

  #modprobe zfs ; zpool version ; sleep 5
  #-----------------------------------------
}

#----------------------------------------
${@:-freebsd freebsd-Release-zfs}

OUT_DIR=${OUT_DIR:-build/${GUEST}}
mkdir -p ${OUT_DIR}
qemu-img create -f qcow2 ${OUT_DIR}/${GUEST}.qcow2 30720M

if [ "1" = "${USE_VIRTINST}" ] ; then
	#-------------- using virtinst ------------------
	CONNECT_OPT=${CONNECT_OPT:---connect qemu:///system}
	VUEFI_OPTS=${VUEFI_OPTS:---boot uefi}

	# NOTE, to convert qemu-system args to libvirt domain XML:
	# eval "echo \"$(< vminstall_qemu.args)\"" > /tmp/install_qemu.args
	# virsh ${CONNECT_OPT} domxml-from-native qemu-argv /tmp/install_qemu.args

	virt-install ${CONNECT_OPT} --memory 2048 --vcpus 2 \
  	--controller usb,model=ehci --controller virtio-serial \
  	--console pty,target_type=virtio --graphics vnc,port=-1 \
  	--network network=default,model=virtio-net,mac=RANDOM \
  	--boot menu=on,cdrom,hd,network --controller scsi,model=virtio-scsi \
  	--disk path=${OUT_DIR}/${GUEST}.qcow2,cache=writeback,discard=unmap,detect_zeroes=unmap,bus=scsi,format=qcow2 \
  	--cdrom=${ISO_PATH} ${VUEFI_OPTS} -n ${GUEST} &

	echo "### Once network connected, transfer needed file(s) ###"
	sleep 30 ; virsh ${CONNECT_OPT} vncdisplay ${GUEST}
	#sleep 5 ; virsh ${CONNECT_OPT} dumpxml ${GUEST} > ${OUT_DIR}/${GUEST}.xml
else
	#------------ using qemu-system-* ---------------
	QUEFI_OPTS=${QUEFI_OPTS:-"-smbios type=0,uefi=on -bios ${STORAGE_DIR}/OVMF/OVMF_CODE.fd"}
	echo "Verify bridge device allowed in /etc/qemu/bridge.conf" ; sleep 3
	cat /etc/qemu/bridge.conf ; sleep 5
	echo "(if needed) Quickly catch boot menu to add kernel boot parameters"
	sleep 5

	qemu-system-x86_64 -machine q35,accel=kvm:hvf:tcg -smp cpus=2 -m size=2048 \
	  -global PIIX4_PM.disable_s3=1 -global PIIX4_PM.disable_s4=1 \
	  -display default,show-cursor=on -boot order=cdn,menu=on -usb \
	  -net nic,model=virtio-net-pci,macaddr=52:54:00:$(openssl rand -hex 3 | sed 's|\(..\)|\1:|g; s|:$||') \
	  ${NET_OPTS:--net bridge,br=br0} \
	  -device virtio-scsi-pci,id=scsi0 -device scsi-hd,drive=hd0 \
	  -drive file=${OUT_DIR}/${GUEST}.qcow2,cache=writeback,discard=unmap,detect-zeroes=unmap,if=none,id=hd0,format=qcow2 \
	  -cdrom ${ISO_PATH} ${QUEFI_OPTS} -name ${GUEST} &

	echo "### Once network connected, transfer needed file(s) ###"
fi

if command -v erb > /dev/null ; then
  erb variant=${variant} init/common/Vagrantfile.erb > ${OUT_DIR}/Vagrantfile ;
elif command -v pystache > /dev/null ; then
  pystache init/common/Vagrantfile.mustache "{\"variant\":\"${variant}\"}" \
    > ${OUT_DIR}/Vagrantfile ;
elif command -v mustache > /dev/null ; then
	cat << EOF >> mustache - init/common/Vagrantfile.mustache > ${OUT_DIR}/Vagrantfile
---
variant: ${variant}
---
EOF
fi

cp -R init/common/catalog.json* init/common/qemu_lxc/vmrun* OVMF/OVMF_CODE.fd ${OUT_DIR}/
sleep 30


#-----------------------------------------
## package manager tools & config needed to install from existing Linux

#debian variants(debian, devuan):
  # (devuan MIRROR: deb.devuan.org/merged)
  # (debian MIRROR: deb.debian.org/debian)
  #  package(s): debootstrap

#void linux: (MIRROR: mirror.clarkson.edu/voidlinux)
  ## dnld: http://${MIRROR}/static/xbps-static-latest.x86_64-musl.tar.xz
  #  package(s): xbps-install.static (download xbps-static tarball)

#arch linux variants(arch, artix):
  #  package(s): pacman, ? libffi

#alpine linux: (MIRROR: dl-cdn.alpinelinux.org/alpine)
  ## dnld: http://${MIRROR}/latest-stable/main/x86_64/apk-tools-static-*.apk
  #  package(s): apk[-tools][.static] (download apk[-tools][-static])

#suse variants(opensuse): (MIRROR: download.opensuse.org)
  #  package(s): zypper, rpm, ? rinse

#----------------------------------------
## (Linux distro) install via chroot
## NOTE, transfer [dir(s) | file(s)]: init/common, init/<variant>

#  [[sgdisk -p | sfdisk -l] /dev/[sv]da | parted /dev/[sv]da -s unit GiB print]
#  sh init/common/disk_setup_vmlinux.sh part_format_vmdisk [sgdisk | sfdisk | parted] [lvm | zfs] [ .. ]
#  sh init/common/disk_setup_vmlinux.sh mount_filesystems [ .. ]

#  sh init/<variant>/[lvm | zfs]-install.sh [hostname [$CRYPTED_PASSWD]]
#----------------------------------------
