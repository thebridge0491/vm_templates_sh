#!/bin/sh -x

# passwd crypted hash: [md5|sha256|sha512] - [$1|$5|$6]$...
# perl -e 'use Term::ReadKey ; print "Password:\n" ; ReadMode "noecho" ; $_=<STDIN> ; ReadMode "normal" ; chomp $_ ; print crypt($_, "\$6\$16CHARACTERSSALT") . "\n"'
# ruby -e "['io/console','digest/sha2'].each {|i| require i} ; puts 'Password:' ; puts STDIN.noecho(&:gets).chomp.crypt(\"\$6\$16CHARACTERSSALT\")"
# python -c "import crypt,getpass ; print(crypt.crypt(getpass.getpass(), \"\$6\$16CHARACTERSSALT\"))"

# nc -l [-p] {port} > file ## nc -w3 {host} {port} < file  # netcat xfr
# ssh user@ipaddr "su -c 'sh -xs - arg1 argN'" < script.sh
# ssh user@ipaddr "sudo sh -xs - arg1 argN" < script.sh  # w/ sudo

## WITHOUT availability of netcat or ssh/scp on system:
##  (host) simple http server for files:
##         php -S localhost:{port} [-t {dir}]
##         ruby -run -e httpd -- -p {port} {dir}
##         python -m http.server {port} [-d {dir}]
##  (host) kill HTTP server process: kill -9 $(pgrep -f 'python -m http\.server')
##  (client) tools:
##    [curl | wget | aria2c | fetch | ftp] http://{host}:{port}/{path}/file

# usage: [MACHINE=x86_64] [VOL_MGR=???] sh vminstall_auto.sh [oshost [GUEST]]
#   (default) [MACHINE=x86_64] [VOL_MGR=zfs] sh vminstall_auto.sh [freebsd [freebsd-x86_64-zfs]]

STORAGE_DIR=${STORAGE_DIR:-$(dirname $0)}
ISOS_PARDIR=${ISOS_PARDIR:-/mnt/Data0/distros} ; MACHINE=${MACHINE:-x86_64}
QEMU_X64_FIRMWARE=${QEMU_X64_FIRMWARE:-/usr/share/OVMF/OVMF_CODE.fd}
QEMU_AA64_FIRMWARE=${QEMU_AA64_FIRMWARE:-/usr/share/AAVMF/AAVMF_CODE.fd}

mkdir -p $HOME/.ssh/publish_krls $HOME/.pki/publish_crls
cp -R $HOME/.ssh/publish_krls init/common/skel/_ssh/
cp -R $HOME/.pki/publish_crls init/common/skel/_pki/

freebsd() {
  VOL_MGR=${VOL_MGR:-zfs} ; variant=freebsd
  init_hostname=${init_hostname:-freebsd-boxv0000}
  GUEST=${1:-freebsd-${MACHINE}-${VOL_MGR}}

  if [ "aarch64" = "${MACHINE}" ] ; then
    ISO_PATH=${ISO_PATH:-$(find ${ISOS_PARDIR}/freebsd -name 'FreeBSD-*-aarch64-disc1.iso' | tail -n1)} ;
    (cd ${ISOS_PARDIR}/freebsd ; sha256sum --ignore-missing -c CHECKSUM.SHA256-FreeBSD-*-RELEASE*-aarch64) ;
  else
    ISO_PATH=${ISO_PATH:-$(find ${ISOS_PARDIR}/freebsd -name 'FreeBSD-*-amd64-disc1.iso' | tail -n1)} ;
    (cd ${ISOS_PARDIR}/freebsd ; sha256sum --ignore-missing -c CHECKSUM.SHA256-FreeBSD-*-RELEASE-amd64) ;
  fi
  sleep 5

  INST_SRC_OPTS=${INST_SRC_OPTS:---cdrom="${ISO_PATH}"}
  tar -cf /tmp/init.tar init/common init/freebsd

  echo "### Once network connected, transfer needed file(s) ###" ; sleep 5

  ## NOTE, saved auto install config: /root/installscript

  ##!! (bsdinstall) navigate to single user: 2
  ##!! if late, Live CD -> root/-

  #mdmfs -s 100m md1 /mnt ; mdmfs -s 100m md2 /tmp ; cd /tmp
  #ifconfig ; dhclient -l /tmp/dhclient.leases -p /tmp/dhclient.lease.{ifdev} {ifdev}

  ## (FreeBSD) install with bsdinstall script
  ## NOTE, transfer [dir(s) | file(s)]: init/common, init/freebsd

  #geom -t
  #[CRYPTED_PASSWD=$CRYPTED_PASSWD] [INIT_HOSTNAME=freebsd-boxv0000] bsdinstall script init/freebsd/zfs-installerconfig
}

debian() {
  VOL_MGR=${VOL_MGR:-lvm} ; variant=debian ; cfg_file=preseed.cfg
  init_hostname=${init_hostname:-devuan-boxv0000}
  #repo_host=${repo_host:-deb.debian.org}
  repo_host=${repo_host:-deb.devuan.org}
  GUEST=${1:-devuan-${MACHINE}-${VOL_MGR}}

  if [ "aarch64" = "${MACHINE}" ] ; then
    ISO_PATH=${ISO_PATH:-$(find ${ISOS_PARDIR}/debian/arm64 -name 'debian-*-arm64-netinst.iso' | tail -n1)} ;
    #ISO_PATH=${ISO_PATH:-$(find ${ISOS_PARDIR}/devuan/arm64 -name 'mini.iso' | tail -n1)} ;
    if [ "$ISO_PATH" ] ; then
      (cd ${ISOS_PARDIR}/debian/arm64 ; sha256sum --ignore-missing -c SHA256SUMS) ;
      #(cd ${ISOS_PARDIR}/devuan/arm64 ; sha256sum --ignore-missing -c SHA256SUMS) ;
    fi ;
    #repo_directory=${repo_directory:-/debian/dists/stable/main/installer-arm64}
    repo_directory=${repo_directory:-/merged/dists/stable/main/installer-arm64}
    
    ##dnld: <mirror>/dists/<version>/main/installer-arm64/current/images/cdrom/{vmlinuz,initrd.gz}
    KERNEL_PATH=${KERNEL_PATH:-$(find ${ISOS_PARDIR}/debian/arm64 -name 'vmlinuz' | tail -n1)}
    INITRD_PATH=${INITRD_PATH:-$(find ${ISOS_PARDIR}/debian/arm64 -name 'initrd.gz' | tail -n1)}
  else
    ISO_PATH=${ISO_PATH:-$(find ${ISOS_PARDIR}/debian -name 'debian-*-amd64-netinst.iso' | tail -n1)} ;
    #ISO_PATH=${ISO_PATH:-$(find ${ISOS_PARDIR}/devuan -name 'devuan_*_amd64*desktop.iso' | tail -n1)} ;
    if [ "$ISO_PATH" ] ; then
      (cd ${ISOS_PARDIR}/debian ; sha256sum --ignore-missing -c SHA256SUMS) ;
      #(cd ${ISOS_PARDIR}/devuan ; sha256sum --ignore-missing -c SHA256SUMS) ;
    fi ;
    #repo_directory=${repo_directory:-/debian/dists/stable/main/installer-amd64}
    repo_directory=${repo_directory:-/merged/dists/stable/main/installer-amd64}
    
    ##dnld: <mirror>/dists/<version>/main/installer-amd64/current/images/hd-media/{vmlinuz,initrd.gz}
    KERNEL_PATH=${KERNEL_PATH:-$(find ${ISOS_PARDIR}/devuan -name 'vmlinuz' | tail -n1)}
    INITRD_PATH=${INITRD_PATH:-$(find ${ISOS_PARDIR}/devuan -name 'initrd.gz' | tail -n1)}
  fi
  sleep 5

  #CFGHOST [http://<host>:<port> | file://]
  EXTRA_ARGS=${EXTRA_ARGS:- auto=true preseed/url=${CFGHOST:-http://10.0.2.1:8080}/${cfg_file} locale=en_US keymap=us console-setup/ask_detect=false domain= hostname=${init_hostname} mirror/http/hostname=${repo_host} mirror/http/directory=${repo_directory}}
  cp init/debian/${VOL_MGR}-preseed.cfg /tmp/${cfg_file}
  tar -cf /tmp/init.tar init/common init/debian

  ## NOTE, debconf-get-selections [--installer] -> auto install cfg
}

alpine() {
  VOL_MGR=${VOL_MGR:-lvm} ; variant=alpine
  init_hostname=${init_hostname:-alpine-boxv0000}
  GUEST=${1:-alpine-${MACHINE}-${VOL_MGR}}

  if [ "aarch64" = "${MACHINE}" ] ; then
    ISO_PATH=${ISO_PATH:-$(find ${ISOS_PARDIR}/alpine -name "alpine-standard-*-${MACHINE}.iso" | tail -n1)} ;
    (cd ${ISOS_PARDIR}/alpine ; sha256sum --ignore-missing -c alpine-standard-*-${MACHINE}.iso.sha256) ;
  else
    ISO_PATH=${ISO_PATH:-$(find ${ISOS_PARDIR}/alpine -name "alpine-extended-*-${MACHINE}.iso" | tail -n1)} ;
    (cd ${ISOS_PARDIR}/alpine ; sha256sum --ignore-missing -c alpine-extended-*-${MACHINE}.iso.sha256) ;
  fi
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
  VOL_MGR=${VOL_MGR:-lvm} ; variant=suse ; cfg_file=autoinst.xml
  init_hostname=${init_hostname:-opensuse-boxv0000}
  repo_host=${repo_host:-download.opensuse.org} ; repo_directory=${repo_directory:-/distribution/openSUSE-current/repo/oss}
  GUEST=${1:-opensuse-${MACHINE}-${VOL_MGR}}

  if [ "aarch64" = "${MACHINE}" ] ; then
    ISO_PATH=${ISO_PATH:-$(find ${ISOS_PARDIR}/opensuse/aarch64 -name "openSUSE-Leap-*-NET-${MACHINE}.iso" | tail -n1)}
    if [ "$ISO_PATH" ] ; then
      (cd ${ISOS_PARDIR}/opensuse/aarch64 ; sha256sum --ignore-missing -c openSUSE-Leap-*-NET-${MACHINE}.iso.sha256) ;
    fi ;
    sleep 5
    
    ##dnld: <mirror>/distribution/<version>/repo/oss/boot/aarch64/loader/{linux,initrd}
    KERNEL_PATH=${KERNEL_PATH:-$(find ${ISOS_PARDIR}/opensuse/aarch64 -name 'linux' | tail -n1)}
    INITRD_PATH=${INITRD_PATH:-$(find ${ISOS_PARDIR}/opensuse/aarch64 -name 'initrd' | tail -n1)}
  else
    ISO_PATH=${ISO_PATH:-$(find ${ISOS_PARDIR}/opensuse -name "openSUSE-Leap-*-NET-${MACHINE}.iso" | tail -n1)}
    if [ "$ISO_PATH" ] ; then
      (cd ${ISOS_PARDIR}/opensuse ; sha256sum --ignore-missing -c openSUSE-Leap-*-NET-${MACHINE}.iso.sha256) ;
    fi ;
    sleep 5
    
    ##dnld: <mirror>/distribution/<version>/repo/oss/boot/x86_64/loader/{linux,initrd}
    KERNEL_PATH=${KERNEL_PATH:-$(find ${ISOS_PARDIR}/opensuse -name 'linux' | tail -n1)}
    INITRD_PATH=${INITRD_PATH:-$(find ${ISOS_PARDIR}/opensuse -name 'initrd' | tail -n1)}
  fi
  
  #CFGHOST [http://<host>:<port> | file://]
  EXTRA_ARGS=${EXTRA_ARGS:- netsetup=dhcp lang=en_US install=http://${repo_host}${repo_directory} hostname=${init_hostname} domain= autoyast=${CFGHOST:-http://10.0.2.1:8080}/${cfg_file} textmode=1}
  cp init/suse/${VOL_MGR}-autoinst.xml /tmp/${cfg_file}
  tar -cf /tmp/init.tar init/common init/suse

  ## NOTE, yast2 clone_system -> auto install config: /root/autoinst.xml
}

redhat() {
  VOL_MGR=${VOL_MGR:-lvm} ; variant=redhat ; cfg_file=anaconda-ks.cfg
  init_hostname=${init_hostname:-rocky-boxv0000} ; RELEASE=${RELEASE:-8}
  # [rocky/8|almalinux/8|centos/8-stream]/BaseOS/${MACHINE}/os | centos/7/os/${MACHINE}]
  repo_host=${repo_host:-dl.rockylinux.org/pub/rocky}
  #repo_host=${repo_host:-repo.almalinux.org/almalinux}
  #repo_host=${repo_host:-mirror.centos.org/centos}
  repo_directory=${repo_directory:-/${RELEASE}/BaseOS/${MACHINE}/os}
  GUEST=${1:-rocky-${MACHINE}-${VOL_MGR}}

  if [ "aarch64" = "${MACHINE}" ] ; then
    ISO_PATH=${ISO_PATH:-$(find ${ISOS_PARDIR}/rocky/aarch64 -name "Rocky-*-${MACHINE}*-boot.iso" | tail -n1)}
    #ISO_PATH=${ISO_PATH:-$(find ${ISOS_PARDIR}/almalinux/aarch64 -name "AlmaLinux-*-${MACHINE}*-boot.iso" | tail -n1)}
    #ISO_PATH=${ISO_PATH:-$(find ${ISOS_PARDIR}/centos/aarch64 -name "CentOS-*-${MACHINE}*-boot.iso" | tail -n1)}
    if [ "$ISO_PATH" ] ; then
      (cd ${ISOS_PARDIR}/rocky/aarch64 ; sha256sum --ignore-missing -c CHECKSUM) ;
      #(cd ${ISOS_PARDIR}/almalinux/aarch64 ; sha256sum --ignore-missing -c CHECKSUM) ;
      #(cd ${ISOS_PARDIR}/centos/aarch64 ; sha256sum --ignore-missing -c CHECKSUM) ;
    fi
    sleep 5
    
    ##dnld: <mirror>/<version>/BaseOS/aarch64/kickstart/images/pxeboot/{vmlinuz,initrd.img}
    KERNEL_PATH=${KERNEL_PATH:-$(find ${ISOS_PARDIR}/rocky -name 'vmlinuz' | tail -n1)}
    INITRD_PATH=${INITRD_PATH:-$(find ${ISOS_PARDIR}/rocky -name 'initrd.img' | tail -n1)}
  else
    ISO_PATH=${ISO_PATH:-$(find ${ISOS_PARDIR}/rocky -name "Rocky-*-${MACHINE}*-boot.iso" | tail -n1)}
    #ISO_PATH=${ISO_PATH:-$(find ${ISOS_PARDIR}/almalinux -name "AlmaLinux-*-${MACHINE}*-boot.iso" | tail -n1)}
    #ISO_PATH=${ISO_PATH:-$(find ${ISOS_PARDIR}/centos -name "CentOS-*-${MACHINE}*-boot.iso" | tail -n1)}
    if [ "$ISO_PATH" ] ; then
      (cd ${ISOS_PARDIR}/rocky ; sha256sum --ignore-missing -c CHECKSUM) ;
      #(cd ${ISOS_PARDIR}/almalinux ; sha256sum --ignore-missing -c CHECKSUM) ;
      #(cd ${ISOS_PARDIR}/centos ; sha256sum --ignore-missing -c CHECKSUM) ;
    fi
    sleep 5
    
    ##dnld: <mirror>/<version>/BaseOS/x86_64/kickstart/images/pxeboot/{vmlinuz,initrd.img}
    KERNEL_PATH=${KERNEL_PATH:-$(find ${ISOS_PARDIR}/rocky -name 'vmlinuz' | tail -n1)}
    INITRD_PATH=${INITRD_PATH:-$(find ${ISOS_PARDIR}/rocky -name 'initrd.img' | tail -n1)}
  fi
  
  #CFGHOST [http://<host>:<port> | file://]
  EXTRA_ARGS=${EXTRA_ARGS:- nomodeset video=1024x768 inst.ks=${CFGHOST:-http://10.0.2.1:8080}/${cfg_file} inst.repo=http://${repo_host}${repo_directory} ip=::::${init_hostname}::dhcp hostname=${init_hostname} inst.selinux=1 inst.enforcing=0 inst.text}
  # systemd.unit=multi-user.target
  cp init/redhat/${VOL_MGR}-anaconda-ks.cfg /tmp/${cfg_file}
  tar -cf /tmp/init.tar init/common init/redhat

  ## NOTE, in kickstart failure to find ks.cfg:
  ##  Alt-Tab to cmdline
  ##  anaconda --kickstart <path>/anaconda-ks.cfg

  ## NOTE, saved auto install config: /root/anaconda-ks.cfg
}

mageia() {
  VOL_MGR=${VOL_MGR:-lvm} ; variant=mageia ; cfg_file=auto_inst_cfg.pl
  init_hostname=${init_hostname:-mageia-boxv0000} ; RELEASE=${RELEASE:-8}
  repo_host=${repo_host:-mirrors.kernel.org/mageia} ; repo_directory=${repo_directory:-/distrib/${RELEASE}/x86_64}
  GUEST=${1:-mageia-x86_64-${VOL_MGR}}

  ISO_PATH=${ISO_PATH:-$(find ${ISOS_PARDIR}/mageia -maxdepth 1 -name "Mageia-*-x86_64*.iso" | tail -n1)}
  if [ "$ISO_PATH" ] ; then
  	(cd ${ISOS_PARDIR}/mageia ; sha512sum --ignore-missing -c Mageia-*-x86_64*.iso.sha512) ;
  fi
  sleep 5
    
  ##dnld: <mirror>/distrib/<version>/x86_64/isolinux/x86_64/{vmlinuz,all.rdz}
  KERNEL_PATH=${KERNEL_PATH:-$(find ${ISOS_PARDIR}/mageia -name 'vmlinuz' | tail -n1)}
  INITRD_PATH=${INITRD_PATH:-$(find ${ISOS_PARDIR}/mageia -name 'all.rdz' | tail -n1)}

  #CFGHOST [http://<host>:<port> | file://]
  EXTRA_ARGS=${EXTRA_ARGS:- automatic=method:http,server:${repo_host},directory:${repo_directory},network:dhcp auto_install=${CFGHOST:-http://10.0.2.1:8080}/${cfg_file} nomodeset text}
  # systemd.unit=multi-user.target
  cp init/mageia/${VOL_MGR}-auto_inst.cfg.pl /tmp/${cfg_file}
  tar -cf /tmp/init.tar init/common init/mageia

  ## NOTE, saved auto install config: /root/drakx/auto_inst_cfg.pl
}

openbsd() {
  VOL_MGR=${VOL_MGR:-std} ; variant=openbsd
  init_hostname=${init_hostname:-openbsd-boxv0000}
  GUEST=${1:-openbsd-${MACHINE}-${VOL_MGR}}

  if [ "aarch64" = "${MACHINE}" ] ; then
    ISO_PATH=${ISO_PATH:-$(find ${ISOS_PARDIR}/openbsd/arm64 -name 'install*.img' | tail -n1)} ;
    (cd ${ISOS_PARDIR}/openbsd/arm64 ; sha256sum --ignore-missing -c SHA256) ;
  else
    ISO_PATH=${ISO_PATH:-$(find ${ISOS_PARDIR}/openbsd/amd64 -name 'install*.iso' | tail -n1)} ;
    (cd ${ISOS_PARDIR}/openbsd/amd64 ; sha256sum --ignore-missing -c SHA256) ;
  fi
  sleep 5

  INST_SRC_OPTS=${INST_SRC_OPTS:---import --disk="${ISO_PATH}"}
  tar -cf /tmp/init.tar init/common init/openbsd

  ## ?? --boot uefi NOT WORKING for iso ??
  #QUEFI_OPTS=" "
  #VUEFI_OPTS=" "
  echo "### Once network connected, transfer needed file(s) ###" ; sleep 5

  ##NOTE, enter shell: S
  ##!! login user/passwd: root/-

  #ifconfig ; dhclient {ifdev}
  #cd /tmp ; (cd /dev ; sh MAKEDEV sd0)
  #fdisk -iy -g -b 960 sd0 ; sync ; fdisk sd0

  ## NOTE, transfer [dir(s) | file(s)]: init/common, init/openbsd

  #export MIRROR=ftp4.usa.openbsd.org/pub/OpenBSD
  #cp init/openbsd/custom.disklabel init/openbsd/install.conf /tmp/
  #sh init/openbsd/autoinstall.sh [$PLAIN_PASSWD]

  ## NOTE, saved install response file: /tmp/i/install.resp
}

#----------------------------------------
${@:-freebsd freebsd-x86_64-zfs}

OUT_DIR=${OUT_DIR:-build/${GUEST}}
mkdir -p ${OUT_DIR}
qemu-img create -f qcow2 ${OUT_DIR}/${GUEST}.qcow2 30720M
if [ "aarch64" = "${MACHINE}" ] ; then
  cp ${QEMU_AA64_FIRMWARE} init/common/qemu_lxc/vmrun_qemu_${MACHINE}.args ${OUT_DIR}/ ;
else
  cp ${QEMU_X64_FIRMWARE} init/common/qemu_lxc/vmrun_bhyve.args init/common/qemu_lxc/vmrun_qemu_${MACHINE}.args ${OUT_DIR}/ ;
fi

if [ "${EXTRA_ARGS}" ] ; then
  python3 -m http.server 8080 -d /tmp  &
  echo "[curl | wget | aria2c | fetch | ftp] http://{host}:{port}/{path}/file" ;
  sleep 5 ;
fi

if [ "1" = "${USE_VIRTINST:-0}" ] ; then
  #-------------- using virtinst ------------------
  CONNECT_OPT=${CONNECT_OPT:---connect qemu:///system}
  VUEFI_OPTS=${VUEFI_OPTS:---boot uefi}
  #INST_SRC_OPTS=${INST_SRC_OPTS:---cdrom="${ISO_PATH}"}
  INST_SRC_OPTS=${INST_SRC_OPTS:---location="http://${repo_host}${repo_directory}"}

  # NOTE, to convert qemu-system args to libvirt domain XML:
  #  eval "echo \"$(< vminstall_qemu.args)\"" > /tmp/install_qemu.args
  #  virsh ${CONNECT_OPT} domxml-from-native qemu-argv /tmp/install_qemu.args

  if [ "${EXTRA_ARGS}" ] ; then
    virt-install ${CONNECT_OPT} --arch ${MACHINE} --memory 2048 --vcpus 2 \
    --controller usb,model=ehci --controller virtio-serial \
    --console pty,target_type=virtio --graphics vnc,port=-1 \
    --network network=default,model=virtio-net,mac=RANDOM \
    --boot menu=on,cdrom,hd,network --controller scsi,model=virtio-scsi \
    --disk path=${OUT_DIR}/${GUEST}.qcow2,cache=writeback,discard=unmap,detect_zeroes=unmap,bus=scsi,format=qcow2 \
    ${INST_SRC_OPTS} ${VUEFI_OPTS} -n ${GUEST} \
    --initrd-inject="/tmp/${cfg_file}" --initrd-inject="/tmp/init.tar" \
    --extra-args="${EXTRA_ARGS}" &
  else
    virt-install ${CONNECT_OPT} --arch ${MACHINE} --memory 2048 --vcpus 2 \
      --controller usb,model=ehci --controller virtio-serial \
      --console pty,target_type=virtio --graphics vnc,port=-1 \
      --network network=default,model=virtio-net,mac=RANDOM \
      --boot menu=on,cdrom,hd,network --controller scsi,model=virtio-scsi \
      --disk path=${OUT_DIR}/${GUEST}.qcow2,cache=writeback,discard=unmap,detect_zeroes=unmap,bus=scsi,format=qcow2 \
      ${INST_SRC_OPTS} ${VUEFI_OPTS} -n ${GUEST} &
  fi ;

  sleep 30 ; virsh ${CONNECT_OPT} vncdisplay ${GUEST} ;
  #sleep 5 ; virsh ${CONNECT_OPT} dumpxml ${GUEST} > ${OUT_DIR}/${GUEST}.xml ;
else
  #------------ using qemu-system-* ---------------
  if [ "$(uname -s)" = "Linux" ] ; then
    echo "Verify bridge device allowed in /etc/qemu/bridge.conf" ; sleep 3 ;
    cat /etc/qemu/bridge.conf ; sleep 5 ;
  fi
  echo "(if needed) Quickly catch boot menu to add kernel boot parameters" ;
  sleep 5 ;

  if [ "${EXTRA_ARGS}" ] ; then
    #APPEND_OPTS="-kernel ${KERNEL_PATH} -append \'${EXTRA_ARGS}\' -initrd ${INITRD_PATH}" ;
    if [ "aarch64" = "${MACHINE}" ] ; then
      QUEFI_OPTS=${QUEFI_OPTS:-"-smbios type=0,uefi=on -bios ${QEMU_AA64_FIRMWARE}"} ;

      qemu-system-aarch64 -cpu cortex-a57 -machine virt,accel=kvm:hvf:tcg,gic-version=3 \
        -smp cpus=2 -m size=2048 -boot order=cdn,menu=on -name ${GUEST} \
        -nic ${NET_OPT:-bridge,br=br0},id=net0,model=virtio-net-pci,mac=52:54:00:$(openssl rand -hex 3 | sed 's|\(..\)|\1:|g; s|:$||') \
        -device qemu-xhci,id=usb -usb -device usb-kbd -device usb-tablet \
        -device virtio-blk-pci,drive=hd0 \
        -drive file=${OUT_DIR}/${GUEST}.qcow2,cache=writeback,discard=unmap,detect-zeroes=unmap,if=none,id=hd0,format=qcow2 \
        -display default,show-cursor=on -vga none -device virtio-gpu-pci \
        ${QUEFI_OPTS} -cdrom ${ISO_PATH} -no-reboot -kernel ${KERNEL_PATH} -append "${EXTRA_ARGS}" -initrd ${INITRD_PATH} &
  else
      QUEFI_OPTS=${QUEFI_OPTS:-"-smbios type=0,uefi=on -bios ${QEMU_X64_FIRMWARE}"}

      qemu-system-x86_64 -machine q35,accel=kvm:hvf:tcg \
        -global PIIX4_PM.disable_s3=1 -global PIIX4_PM.disable_s4=1 \
        -smp cpus=2 -m size=2048 -boot order=cdn,menu=on -name ${GUEST} \
        -nic ${NET_OPT:-bridge,br=br0},id=net0,model=virtio-net-pci,mac=52:54:00:$(openssl rand -hex 3 | sed 's|\(..\)|\1:|g; s|:$||') \
        -device qemu-xhci,id=usb -usb -device usb-kbd -device usb-tablet \
        -device virtio-scsi-pci,id=scsi0 -device scsi-hd,drive=hd0 \
        -drive file=${OUT_DIR}/${GUEST}.qcow2,cache=writeback,discard=unmap,detect-zeroes=unmap,if=none,id=hd0,format=qcow2 \
        -display default,show-cursor=on \
        ${QUEFI_OPTS} -cdrom ${ISO_PATH} -no-reboot -kernel ${KERNEL_PATH} -append "${EXTRA_ARGS}" -initrd ${INITRD_PATH} &
    fi ;
  else
    if [ "aarch64" = "${MACHINE}" ] ; then
      QUEFI_OPTS=${QUEFI_OPTS:-"-smbios type=0,uefi=on -bios ${QEMU_AA64_FIRMWARE}"} ;

      qemu-system-aarch64 -cpu cortex-a57 -machine virt,accel=kvm:hvf:tcg,gic-version=3 \
        -smp cpus=2 -m size=2048 -boot order=cdn,menu=on -name ${GUEST} \
        -nic ${NET_OPT:-bridge,br=br0},id=net0,model=virtio-net-pci,mac=52:54:00:$(openssl rand -hex 3 | sed 's|\(..\)|\1:|g; s|:$||') \
        -device qemu-xhci,id=usb -usb -device usb-kbd -device usb-tablet \
        -device virtio-blk-pci,drive=hd0 \
        -drive file=${OUT_DIR}/${GUEST}.qcow2,cache=writeback,discard=unmap,detect-zeroes=unmap,if=none,id=hd0,format=qcow2 \
        -display default,show-cursor=on -vga none -device virtio-gpu-pci \
        ${QUEFI_OPTS} -cdrom ${ISO_PATH} -no-reboot &
    else
      QUEFI_OPTS=${QUEFI_OPTS:-"-smbios type=0,uefi=on -bios ${QEMU_X64_FIRMWARE}"}

      qemu-system-x86_64 -machine q35,accel=kvm:hvf:tcg \
        -global PIIX4_PM.disable_s3=1 -global PIIX4_PM.disable_s4=1 \
        -smp cpus=2 -m size=2048 -boot order=cdn,menu=on -name ${GUEST} \
        -nic ${NET_OPT:-bridge,br=br0},id=net0,model=virtio-net-pci,mac=52:54:00:$(openssl rand -hex 3 | sed 's|\(..\)|\1:|g; s|:$||') \
        -device qemu-xhci,id=usb -usb -device usb-kbd -device usb-tablet \
        -device virtio-scsi-pci,id=scsi0 -device scsi-hd,drive=hd0 \
        -drive file=${OUT_DIR}/${GUEST}.qcow2,cache=writeback,discard=unmap,detect-zeroes=unmap,if=none,id=hd0,format=qcow2 \
        -display default,show-cursor=on \
        ${QUEFI_OPTS} -cdrom ${ISO_PATH} -no-reboot &
    fi ;
  fi ;
  echo "### Once network connected, transfer needed file(s) ###" ;
fi

if command -v erb > /dev/null ; then
  erb variant=${variant} init/common/Vagrantfile_libvirt.erb > ${OUT_DIR}/Vagrantfile ;
elif command -v pystache > /dev/null ; then
  pystache init/common/Vagrantfile_libvirt.mustache "{\"variant\":\"${variant}\"}" \
    > ${OUT_DIR}/Vagrantfile ;
elif command -v mustache > /dev/null ; then
  cat << EOF >> mustache - init/common/Vagrantfile_libvirt.mustache > ${OUT_DIR}/Vagrantfile
---
variant: ${variant}
---
EOF
fi

if [ "${EXTRA_ARGS}" ] ; then
  echo "to kill HTTP server process: kill -9 \$(pgrep -f 'python -m http\.server')" ;
fi
cp -R init/common/catalog.json* init/common/qemu_lxc/vmrun.sh ${OUT_DIR}/
sleep 30
