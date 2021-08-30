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

# usage: [VOL_MGR=???] sh vminstall_auto.sh [oshost [GUEST]]
#   (default) [VOL_MGR=zfs] sh vminstall_auto.sh [freebsd [freebsd-Release-zfs]]

USE_VIRTINST=${USE_VIRTINST:-1} ; STORAGE_DIR=${STORAGE_DIR:-$(dirname $0)}
ISOS_PARDIR=${ISOS_PARDIR:-/mnt/Data0/distros}

mkdir -p $HOME/.ssh/publish_krls $HOME/.pki/publish_crls
cp -R $HOME/.ssh/publish_krls init/common/skel/_ssh/
cp -R $HOME/.pki/publish_crls init/common/skel/_pki/

freebsd() {
  VOL_MGR=${VOL_MGR:-zfs} ; variant=freebsd
  init_hostname=${init_hostname:-freebsd-boxv0000}
  GUEST=${1:-freebsd-Release-${VOL_MGR}}

  ISO_PATH=${ISO_PATH:-$(find ${ISOS_PARDIR}/freebsd -name 'FreeBSD-*-amd64-disc1.iso' | tail -n1)}
  (cd ${ISOS_PARDIR}/freebsd ; sha256sum --ignore-missing -c CHECKSUM.SHA256-FreeBSD-*-RELEASE-amd64)
  sleep 5

  INST_SRC_OPTS=${INST_SRC_OPTS:---cdrom="${ISO_PATH}"}
  tar -cf /tmp/init.tar init/common init/freebsd

  echo "### Once network connected, transfer needed file(s) ###" ; sleep 5

  ## NOTE, saved auto install config: /root/installscript

  ##!! (bsdinstall) navigate to single user: 2
  ##!! if late, Live CD -> root/-

  #mdmfs -s 100m md1 /tmp ; cd /tmp ; ifconfig
  #dhclient -l /tmp/dhclient.leases -p /tmp/dhclient.lease.{ifdev} {ifdev}

  ## (FreeBSD) install with bsdinstall script
  ## NOTE, transfer [dir(s) | file(s)]: init/common, init/freebsd

  #geom -t
  #[CRYPTED_PASSWD=$CRYPTED_PASSWD] [INIT_HOSTNAME=freebsd-boxv0000] bsdinstall script init/freebsd/zfs-installerconfig
}

debian() {
  VOL_MGR=${VOL_MGR:-lvm} ; variant=debian
  init_hostname=${init_hostname:-devuan-boxv0000}
  #repo_host=${repo_host:-deb.debian.org} ; repo_directory=${repo_directory:-/debian}
  repo_host=${repo_host:-deb.devuan.org} ; repo_directory=${repo_directory:-/merged}
  GUEST=${1:-devuan-Stable-${VOL_MGR}}

  #ISO_PATH=${ISO_PATH:-$(find ${ISOS_PARDIR}/debian -name 'debian-*-amd64-*-CD-1.iso' | tail -n1)}
  ISO_PATH=${ISO_PATH:-$(find ${ISOS_PARDIR}/devuan -name 'devuan_*_amd64*desktop.iso' | tail -n1)}
  if [ ! "" = "$ISO_PATH" ] ; then
    #(cd ${ISOS_PARDIR}/debian ; sha256sum --ignore-missing -c SHA256SUMS) ;
    (cd ${ISOS_PARDIR}/devuan ; sha256sum --ignore-missing -c SHA256SUMS) ;
    sleep 5 ;
  fi

  INST_SRC_OPTS=${INST_SRC_OPTS:---location="http://${repo_host}${repo_directory}/dists/stable/main/installer-amd64"}
  #INST_SRC_OPTS=${INST_SRC_OPTS:---location="${ISO_PATH}"}
  INITRD_INJECT_OPTS=${INITRD_INJECT_OPTS:---initrd-inject="/tmp/preseed.cfg" --initrd-inject="/tmp/init.tar"}
  EXTRA_ARGS_OPTS=${EXTRA_ARGS_OPTS:---extra-args="auto=true preseed/url=file:///preseed.cfg locale=en_US keymap=us console-setup/ask_detect=false domain= hostname=${init_hostname} mirror/http/hostname=${repo_host} mirror/http/directory=${repo_directory}"}
  cp init/debian/${VOL_MGR}-preseed.cfg /tmp/preseed.cfg
  tar -cf /tmp/init.tar init/common init/debian

  ## NOTE, debconf-get-selections [--installer] -> auto install cfg
}

alpine() {
  VOL_MGR=${VOL_MGR:-lvm} ; variant=alpine
  init_hostname=${init_hostname:-alpine-boxv0000}
  GUEST=${1:-alpine-Stable-${VOL_MGR}}

  ISO_PATH=${ISO_PATH:-$(find ${ISOS_PARDIR}/alpine -name 'alpine-extended-*-x86_64.iso' | tail -n1)}
  (cd ${ISOS_PARDIR}/alpine ; sha256sum --ignore-missing -c alpine-extended-*-x86_64.iso.sha256)
  sleep 5

  INST_SRC_OPTS=${INST_SRC_OPTS:---cdrom="${ISO_PATH}"}
  tar -cf /tmp/init.tar init/common init/alpine

  echo "### Once network connected, transfer needed file(s) ###" ; sleep 5

  ##!! login user/passwd: root/-

  #ifconfig ; ifconfig {ifdev} up ; udhcpc -i {ifdev} ; cd /tmp

  ## NOTE, transfer [dir(s) | file(s)]: init/common, init/alpine

  #service sshd stop
  #export MIRROR=dl-cdn.alpinelinux.org/alpine
  #APKREPOSOPTS=http://${MIRROR}/latest-stable/main BOOT_SIZE=200 BOOTLOADER=grub DISKLABEL=gpt setup-alpine -f init/alpine/lvm-answers
  # .. reboot
  # .. after reboot
  #sh init/alpine/post_autoinstall.sh [$CRYPTED_PASSWD]
}

suse() {
  VOL_MGR=${VOL_MGR:-lvm} ; RELEASE=${RELEASE:-15.2} ; variant=suse
  init_hostname=${init_hostname:-opensuse-boxv0000}
  repo_host=${repo_host:-download.opensuse.org} ; repo_directory=${repo_directory:-/distribution/leap/${RELEASE}/repo/oss}
  GUEST=${1:-opensuse-Stable-${VOL_MGR}}

  ISO_PATH=${ISO_PATH:-$(find ${ISOS_PARDIR}/opensuse -name 'openSUSE-Leap-*-NET-x86_64.iso' | tail -n1)}
  if [ ! "" = "$ISO_PATH" ] ; then
    (cd ${ISOS_PARDIR}/opensuse ; sha256sum --ignore-missing -c openSUSE-Leap-*-NET-x86_64.iso.sha256) ;
    sleep 5 ;
  fi

  #INST_SRC_OPTS=${INST_SRC_OPTS:---location="${ISO_PATH}"}
  INST_SRC_OPTS=${INST_SRC_OPTS:---location="http://${repo_host}${repo_directory}"}
  INITRD_INJECT_OPTS=${INITRD_INJECT_OPTS:---initrd-inject="/tmp/autoinst.xml" --initrd-inject="/tmp/init.tar"}
  EXTRA_ARGS_OPTS=${EXTRA_ARGS_OPTS:---extra-args="netsetup=dhcp lang=en_US install=http://${repo_host}${repo_directory} hostname=${init_hostname} domain= autoyast=file:///autoinst.xml textmode=1"}
  cp init/suse/${VOL_MGR}-autoinst.xml /tmp/autoinst.xml
  tar -cf /tmp/init.tar init/common init/suse

  ## NOTE, yast2 clone_system -> auto install config: /root/autoinst.xml
}

redhat() {
  VOL_MGR=${VOL_MGR:-lvm} ; RELEASE=${RELEASE:-8} ; variant=redhat
  init_hostname=${init_hostname:-centos-boxv0000}
  #repo_host=${repo_host:-dl.rockylinux.org/pub/rocky}
  #repo_host=${repo_host:-repo.almalinux.org/almalinux}
  repo_host=${repo_host:-mirror.centos.org/centos}
  # [rocky/8|almalinux/8|centos/8-stream]/BaseOS/x86_64/os | centos/7/os/x86_64]
  repo_directory=${repo_directory:-/${RELEASE}/BaseOS/x86_64/os}
  GUEST=${1:-centos-Release-${VOL_MGR}}

  #ISO_PATH=${ISO_PATH:-$(find ${ISOS_PARDIR}/rocky -name 'Rocky-*-x86_64*-boot.iso' | tail -n1)}
  #ISO_PATH=${ISO_PATH:-$(find ${ISOS_PARDIR}/almalinux -name 'AlmaLinux-*-x86_64*-boot.iso' | tail -n1)}
  ISO_PATH=${ISO_PATH:-$(find ${ISOS_PARDIR}/centos -name 'CentOS-*-x86_64*-boot.iso' | tail -n1)}
  if [ ! "" = "$ISO_PATH" ] ; then
    #(cd ${ISOS_PARDIR}/rocky ; sha256sum --ignore-missing -c CHECKSUM) ;
    #(cd ${ISOS_PARDIR}/almalinux ; sha256sum --ignore-missing -c CHECKSUM) ;
    (cd ${ISOS_PARDIR}/centos ; sha256sum --ignore-missing -c CHECKSUM) ;
    sleep 5 ;
  fi

  #INST_SRC_OPTS=${INST_SRC_OPTS:---location="${ISO_PATH}"}
  INST_SRC_OPTS=${INST_SRC_OPTS:---location="http://${repo_host}${repo_directory}"}
  INITRD_INJECT_OPTS=${INITRD_INJECT_OPTS:---initrd-inject="/tmp/anaconda-ks.cfg" --initrd-inject="/tmp/init.tar"}
  EXTRA_ARGS_OPTS=${EXTRA_ARGS_OPTS:---extra-args="inst.ks=file:///anaconda-ks.cfg inst.repo=http://${repo_host}${repo_directory} ip=::::${init_hostname}::dhcp hostname=${init_hostname} nomodeset video=1024x768 selinux=1 enforcing=0 text inst.text"}
  # systemd.unit=multi-user.target
  cp init/redhat/${VOL_MGR}-anaconda-ks.cfg /tmp/anaconda-ks.cfg
  tar -cf /tmp/init.tar init/common init/redhat

  ## NOTE, in kickstart failure to find ks.cfg:
  ##  Alt-Tab to cmdline
  ##  anaconda --kickstart <path>/anaconda-ks.cfg

  ## NOTE, saved auto install config: /root/anaconda-ks.cfg
}

mageia() {
  VOL_MGR=${VOL_MGR:-lvm} ; RELEASE=${RELEASE:-7.1} ; variant=mageia
  init_hostname=${init_hostname:-mageia-boxv0000}
  repo_host=${repo_host:-mirrors.kernel.org/mageia} ; repo_directory=${repo_directory:-/distrib/${RELEASE}/x86_64}
  GUEST=${1:-mageia-Release-${VOL_MGR}}

  ISO_PATH=${ISO_PATH:-$(find ${ISOS_PARDIR}/mageia -maxdepth 1 -name 'Mageia-*-x86_64*.iso' | tail -n1)}
  if [ ! "" = "$ISO_PATH" ] ; then
  	(cd ${ISOS_PARDIR}/mageia ; sha512sum --ignore-missing -c Mageia-*-x86_64*.iso.sha512) ;
    sleep 5 ;
  fi

  #INST_SRC_OPTS=${INST_SRC_OPTS:---location="${ISO_PATH}"}
  INST_SRC_OPTS=${INST_SRC_OPTS:---location="http://${repo_host}${repo_directory}"}
  INITRD_INJECT_OPTS=${INITRD_INJECT_OPTS:---initrd-inject="/tmp/auto_inst.cfg.pl" --initrd-inject="/tmp/init.tar"}
  EXTRA_ARGS_OPTS=${EXTRA_ARGS_OPTS:---extra-args="automatic=method:http,server:${repo_host},directory:${repo_directory},network:dhcp auto_install=auto_inst.cfg.pl nomodeset text"}
  # systemd.unit=multi-user.target
  cp init/mageia/${VOL_MGR}-auto_inst.cfg.pl /tmp/auto_inst.cfg.pl
  tar -cf /tmp/init.tar init/common init/mageia

  ## NOTE, saved auto install config: /root/drakx/auto_inst_cfg.pl
}

openbsd() {
  VOL_MGR=${VOL_MGR:-std} ; variant=openbsd
  init_hostname=${init_hostname:-openbsd-boxv0000}
  GUEST=${1:-openbsd-Release-${VOL_MGR}}

  ISO_PATH=${ISO_PATH:-$(find ${ISOS_PARDIR}/openbsd -name 'install*.img' | tail -n1)}
  (cd ${ISOS_PARDIR}/openbsd ; sha256sum --ignore-missing -c SHA256)
  sleep 5

  INST_SRC_OPTS=${INST_SRC_OPTS:---import --disk="${ISO_PATH}"}
  tar -cf /tmp/init.tar init/common init/openbsd

  ## ?? --boot uefi NOT WORKING for iso ??
  #QUEFI_OPTS=" "
  #VUEFI_OPTS=" "
  echo "### Once network connected, transfer needed file(s) ###" ; sleep 5

  ##NOTE, enter shell: S
  ##!! login user/passwd: root/-

  #ifconfig
  #dhclient {ifdev} ; cd /tmp ; (cd /dev ; sh MAKEDEV sd0)
  #fdisk -iy -g -b 960 sd0 ; sync ; fdisk sd0

  ## NOTE, transfer [dir(s) | file(s)]: init/common, init/openbsd

  #export MIRROR=ftp4.usa.openbsd.org/pub/OpenBSD
  #cp init/openbsd/custom.disklabel init/openbsd/install.conf /tmp/
  #sh init/openbsd/autoinstall.sh [$PLAIN_PASSWD]

  ## NOTE, saved install response file: /tmp/i/install.resp
}

#----------------------------------------
${@:-freebsd}

OUT_DIR=${OUT_DIR:-build/${GUEST}}
mkdir -p ${OUT_DIR}
qemu-img create -f qcow2 ${OUT_DIR}/${GUEST}.qcow2 30720M

if [ "1" = "${USE_VIRTINST}" ] ; then
	#-------------- using virtinst ------------------
	CONNECT_OPT=${CONNECT_OPT:---connect qemu:///system}
	VUEFI_OPTS=${VUEFI_OPTS:---boot uefi}

	# NOTE, to convert qemu-system args to libvirt domain XML:
	#  eval "echo \"$(< vminstall_qemu.args)\"" > /tmp/install_qemu.args
	#  virsh ${CONNECT_OPT} domxml-from-native qemu-argv /tmp/install_qemu.args

	if [ "" = "${EXTRA_ARGS_OPTS}" ] ; then
		virt-install ${CONNECT_OPT} --memory 2048 --vcpus 2 \
  		--controller usb,model=ehci --controller virtio-serial \
  		--console pty,target_type=virtio --graphics vnc,port=-1 \
  		--network network=default,model=virtio-net,mac=RANDOM \
  		--boot menu=on,cdrom,hd,network --controller scsi,model=virtio-scsi \
  		--disk path=${OUT_DIR}/${GUEST}.qcow2,cache=writeback,discard=unmap,detect_zeroes=unmap,bus=scsi,format=qcow2 \
  		${INST_SRC_OPTS} ${VUEFI_OPTS} -n ${GUEST} ${INITRD_INJECT_OPTS} &
	else
		virt-install ${CONNECT_OPT} --memory 2048 --vcpus 2 \
  		--controller usb,model=ehci --controller virtio-serial \
  		--console pty,target_type=virtio --graphics vnc,port=-1 \
  		--network network=default,model=virtio-net,mac=RANDOM \
  		--boot menu=on,cdrom,hd,network --controller scsi,model=virtio-scsi \
  		--disk path=${OUT_DIR}/${GUEST}.qcow2,cache=writeback,discard=unmap,detect_zeroes=unmap,bus=scsi,format=qcow2 \
  		${INST_SRC_OPTS} ${VUEFI_OPTS} -n ${GUEST} ${INITRD_INJECT_OPTS} \
  		"${EXTRA_ARGS_OPTS}" &
	fi ;

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
