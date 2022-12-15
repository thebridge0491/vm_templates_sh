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

# usage: [VOL_MGR=???] sh vminstall_auto.sh [oshost_machine [GUEST]]
#   (default) [VOL_MGR=std] sh vminstall_auto.sh [freebsd_x86_64 [freebsd-x86_64-std]]

STORAGE_DIR=${STORAGE_DIR:-$(dirname $0)}
ISOS_PARDIR=${ISOS_PARDIR:-/mnt/Data0/distros}
FIRMWARE_QEMU_X64=${FIRMWARE_QEMU_X64:-/usr/share/OVMF/OVMF_CODE.fd}
FIRMWARE_QEMU_AA64=${FIRMWARE_QEMU_AA64:-/usr/share/AAVMF/AAVMF_CODE.fd}


_prep() {
  mkdir -p $HOME/.ssh/publish_krls $HOME/.pki/publish_crls
  cp -a $HOME/.ssh/publish_krls init/common/skel/_ssh/
  cp -a $HOME/.pki/publish_crls init/common/skel/_pki/

  OUT_DIR=${OUT_DIR:-build/${GUEST}}
  mkdir -p ${OUT_DIR}
  qemu-img create -f qcow2 ${OUT_DIR}/${GUEST}.qcow2 30720M

  if [ ! "${EXTRA_ARGS}" ] || [ ! "${EXTRA_ARGS}" = " " ] ; then
    ${PYTHON:-python3} -m http.server 8080 -d /tmp  &
    echo "[curl | wget | aria2c | fetch | ftp] http://{host}:{port}/{path}/file" ;
    sleep 5 ;
  fi
}

_finish() {
  if [ ! "${EXTRA_ARGS}" ] || [ ! "${EXTRA_ARGS}" = " " ] ; then
    echo "to kill HTTP server process: kill -9 \$(pgrep -f 'python -m http\.server')" ;
  fi

  if command -v erb > /dev/null ; then
    erb variant=${variant} init/common/Vagrantfile_libvirt.erb \
      > ${OUT_DIR}/Vagrantfile ;
  elif command -v chevron > /dev/null ; then
    echo "{\"variant\":\"${variant}\"}" | chevron -d /dev/stdin \
      init/common/Vagrantfile_libvirt.mustache > ${OUT_DIR}/Vagrantfile ;
  elif command -v pystache > /dev/null ; then
    pystache init/common/Vagrantfile_libvirt.mustache \
      "{\"variant\":\"${variant}\"}" > ${OUT_DIR}/Vagrantfile ;
  elif command -v mustache > /dev/null ; then
    echo "{\"variant\":\"${variant}\"}" | mustache - init/common/Vagrantfile_libvirt.mustache > ${OUT_DIR}/Vagrantfile ;
  fi
  cp -a init/common/catalog.json* init/common/qemu_lxc/vmrun.sh ${OUT_DIR}/
  sleep 30
}

_install_x86_64() {
  cp -a ${FIRMWARE_QEMU_X64} init/common/qemu_lxc/vmrun_bhyve.args init/common/qemu_lxc/vmrun_qemu_x86_64.args ${OUT_DIR}/

  if [ "1" = "${USE_VIRTINST:-0}" ] ; then
    #-------------- using virtinst ------------------
    CONNECT_OPT=${CONNECT_OPT:---connect qemu:///system}
    VUEFI_OPTS=${VUEFI_OPTS:---boot uefi}
    #INST_SRC_OPTS=${INST_SRC_OPTS:---cdrom="${ISO_PATH}"}
    INST_SRC_OPTS=${INST_SRC_OPTS:---location="http://${repo_host}${repo_directory}"}

    # NOTE, to convert qemu-system args to libvirt domain XML:
    #  eval "echo \"$(< vminstall_qemu.args)\"" > /tmp/install_qemu.args
    #  virsh ${CONNECT_OPT} domxml-from-native qemu-argv /tmp/install_qemu.args

    if [ ! "${EXTRA_ARGS}" ] || [ ! "${EXTRA_ARGS}" = " " ] ; then
      virt-install ${CONNECT_OPT} --arch x86_64 --memory 2048 --vcpus 2 \
      --controller usb,model=ehci --controller virtio-serial \
      --console pty,target_type=virtio --graphics vnc,port=-1 \
      --network network=default,model=virtio-net,mac=RANDOM \
      --boot menu=on,cdrom,hd,network --controller scsi,model=virtio-scsi \
      --disk path=${OUT_DIR}/${GUEST}.qcow2,cache=writeback,discard=unmap,detect_zeroes=unmap,bus=scsi,format=qcow2 \
      ${INST_SRC_OPTS} ${VUEFI_OPTS} -n ${GUEST} \
      --initrd-inject="/tmp/${cfg_file}" --initrd-inject="/tmp/scripts.tar" \
      --extra-args="${EXTRA_ARGS}" &
    else
      virt-install ${CONNECT_OPT} --arch x86_64 --memory 2048 --vcpus 2 \
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
    QUEFI_OPTS=${QUEFI_OPTS:-"-smbios type=0,uefi=on -bios ${FIRMWARE_QEMU_X64}"}
    if [ "$(uname -s)" = "Linux" ] ; then
      echo "Verify bridge device allowed in /etc/qemu/bridge.conf" ; sleep 3 ;
      cat /etc/qemu/bridge.conf ; sleep 5 ;
    fi
    echo "(if needed) Quickly catch boot menu to add kernel boot parameters" ;
    sleep 5 ;

    if [ ! "${EXTRA_ARGS}" ] || [ ! "${EXTRA_ARGS}" = " " ] ; then
      #APPEND_OPTS="-kernel ${KERNEL_PATH} -append \'${EXTRA_ARGS}\' -initrd ${INITRD_PATH}" ;

      qemu-system-x86_64 -machine q35,accel=kvm:hvf:tcg \
        -global PIIX4_PM.disable_s3=1 -global PIIX4_PM.disable_s4=1 \
        -smp cpus=2 -m size=2048 -boot order=cdn,menu=on -name ${GUEST} \
        -nic ${NET_OPT:-bridge,br=br0},id=net0,model=virtio-net-pci,mac=52:54:00:$(openssl rand -hex 3 | sed 's|\(..\)|\1:|g; s|:$||') \
        -device qemu-xhci,id=usb -usb -device usb-kbd -device usb-tablet \
        -device virtio-scsi-pci,id=scsi0 -device scsi-hd,drive=hd0 \
        -drive file=${OUT_DIR}/${GUEST}.qcow2,cache=writeback,discard=unmap,detect-zeroes=unmap,if=none,id=hd0,format=qcow2 \
        -display default,show-cursor=on -vga none -device qxl-vga,vgamem_mb=64 \
        ${QUEFI_OPTS} ${CDROM_OPT:--cdrom ${ISO_PATH}} -no-reboot -kernel ${KERNEL_PATH} -append "${EXTRA_ARGS}" -initrd ${INITRD_PATH} &
    else
      qemu-system-x86_64 -machine q35,accel=kvm:hvf:tcg \
        -global PIIX4_PM.disable_s3=1 -global PIIX4_PM.disable_s4=1 \
        -smp cpus=2 -m size=2048 -boot order=cdn,menu=on -name ${GUEST} \
        -nic ${NET_OPT:-bridge,br=br0},id=net0,model=virtio-net-pci,mac=52:54:00:$(openssl rand -hex 3 | sed 's|\(..\)|\1:|g; s|:$||') \
        -device qemu-xhci,id=usb -usb -device usb-kbd -device usb-tablet \
        -device virtio-scsi-pci,id=scsi0 -device scsi-hd,drive=hd0 \
        -drive file=${OUT_DIR}/${GUEST}.qcow2,cache=writeback,discard=unmap,detect-zeroes=unmap,if=none,id=hd0,format=qcow2 \
        -display default,show-cursor=on -vga none -device qxl-vga,vgamem_mb=64 \
        ${QUEFI_OPTS} ${CDROM_OPT:--cdrom ${ISO_PATH}} -no-reboot &
    fi ;
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
    #INST_SRC_OPTS=${INST_SRC_OPTS:---cdrom="${ISO_PATH}"}
    INST_SRC_OPTS=${INST_SRC_OPTS:---location="http://${repo_host}${repo_directory}"}

    # NOTE, to convert qemu-system args to libvirt domain XML:
    #  eval "echo \"$(< vminstall_qemu.args)\"" > /tmp/install_qemu.args
    #  virsh ${CONNECT_OPT} domxml-from-native qemu-argv /tmp/install_qemu.args

    if [ ! "${EXTRA_ARGS}" ] || [ ! "${EXTRA_ARGS}" = " " ] ; then
      virt-install ${CONNECT_OPT} --arch aarch64 --memory 2048 --vcpus 2 \
      --controller usb,model=ehci --controller virtio-serial \
      --console pty,target_type=virtio --graphics vnc,port=-1 \
      --network network=default,model=virtio-net,mac=RANDOM \
      --boot menu=on,cdrom,hd,network --controller scsi,model=virtio-scsi \
      --disk path=${OUT_DIR}/${GUEST}.qcow2,cache=writeback,discard=unmap,detect_zeroes=unmap,bus=scsi,format=qcow2 \
      ${INST_SRC_OPTS} ${VUEFI_OPTS} -n ${GUEST} \
      --initrd-inject="/tmp/${cfg_file}" --initrd-inject="/tmp/scripts.tar" \
      --extra-args="${EXTRA_ARGS}" &
    else
      virt-install ${CONNECT_OPT} --arch aarch64 --memory 2048 --vcpus 2 \
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
    QUEFI_OPTS=${QUEFI_OPTS:-"-smbios type=0,uefi=on -bios ${FIRMWARE_QEMU_AA64}"}
    if [ "$(uname -s)" = "Linux" ] ; then
      echo "Verify bridge device allowed in /etc/qemu/bridge.conf" ; sleep 3 ;
      cat /etc/qemu/bridge.conf ; sleep 5 ;
    fi
    echo "(if needed) Quickly catch boot menu to add kernel boot parameters" ;
    sleep 5 ;

    if [ ! "${EXTRA_ARGS}" ] || [ ! "${EXTRA_ARGS}" = " " ] ; then
      #APPEND_OPTS="-kernel ${KERNEL_PATH} -append \'${EXTRA_ARGS}\' -initrd ${INITRD_PATH}" ;
      qemu-system-aarch64 -cpu cortex-a57 -machine virt,gic-version=3,acpi=off,accel=kvm:hvf:tcg \
        -smp cpus=2 -m size=2048 -boot order=cdn,menu=on -name ${GUEST} \
        -nic ${NET_OPT:-bridge,br=br0},id=net0,model=virtio-net-pci,mac=52:54:00:$(openssl rand -hex 3 | sed 's|\(..\)|\1:|g; s|:$||') \
        -device qemu-xhci,id=usb -usb -device usb-kbd -device usb-tablet \
        -device virtio-blk-pci,drive=hd0 \
        -drive file=${OUT_DIR}/${GUEST}.qcow2,cache=writeback,discard=unmap,detect-zeroes=unmap,if=none,id=hd0,format=qcow2 \
        -display default,show-cursor=on -vga none -device virtio-gpu-pci \
        ${QUEFI_OPTS} ${CDROM_OPT:--cdrom ${ISO_PATH}} -no-reboot -kernel ${KERNEL_PATH} -append "${EXTRA_ARGS}" -initrd ${INITRD_PATH} &
    else
      qemu-system-aarch64 -cpu cortex-a57 -machine virt,gic-version=3,acpi=off,accel=kvm:hvf:tcg \
        -smp cpus=2 -m size=2048 -boot order=cdn,menu=on -name ${GUEST} \
        -nic ${NET_OPT:-bridge,br=br0},id=net0,model=virtio-net-pci,mac=52:54:00:$(openssl rand -hex 3 | sed 's|\(..\)|\1:|g; s|:$||') \
        -device qemu-xhci,id=usb -usb -device usb-kbd -device usb-tablet \
        -device virtio-blk-pci,drive=hd0 \
        -drive file=${OUT_DIR}/${GUEST}.qcow2,cache=writeback,discard=unmap,detect-zeroes=unmap,if=none,id=hd0,format=qcow2 \
        -display default,show-cursor=on -vga none -device virtio-gpu-pci \
        ${QUEFI_OPTS} ${CDROM_OPT:--cdrom ${ISO_PATH}} -no-reboot &
    fi ;
    echo "### Once network connected, transfer needed file(s) ###" ;
  fi
  _finish
}
#----------------------------------------


_freebsd() {
  INST_SRC_OPTS=${INST_SRC_OPTS:---cdrom="${ISO_PATH}"}

  tar -cf /tmp/scripts.tar init/common init/freebsd -C scripts freebsd
  ## NOTE, saved auto install config: /root/installscript

  echo "### Once network connected, transfer needed file(s) ###" ; sleep 5

  ##!! (bsdinstall) navigate to single user: 2
  ##!! if late, Live CD -> root/-

  #mdmfs -s 100m md1 /mnt ; mdmfs -s 100m md2 /tmp ; cd /tmp
  #ifconfig ; dhclient -l /tmp/dhclient.leases -p /tmp/dhclient.lease.{ifdev} {ifdev}

  ## (FreeBSD) install with bsdinstall script
  ## NOTE, transfer [dir(s) | file(s)]: init/common, init/freebsd

  #geom -t
  #[PASSWD_CRYPTED=$PASSWD_CRYPTED] [INIT_HOSTNAME=freebsd-boxv0000] bsdinstall script init/freebsd/[std | zfs]-installscript
}
freebsd_x86_64() {
  VOL_MGR=${VOL_MGR:-std} ; variant=freebsd
  init_hostname=${init_hostname:-${variant}-boxv0000}
  GUEST=${1:-${variant}-x86_64-${VOL_MGR}}

  ISO_PATH=${ISO_PATH:-$(find ${ISOS_PARDIR}/freebsd -name 'FreeBSD-*-amd64-disc1.iso' | tail -n1)}
  (cd ${ISOS_PARDIR}/freebsd ; sha256sum --ignore-missing -c CHECKSUM.SHA256-FreeBSD-*-RELEASE-amd64)

  sleep 5 ; _freebsd ; _prep ; sleep 3 ; _install_x86_64
}
freebsd_aarch64() {
  VOL_MGR=${VOL_MGR:-std} ; variant=freebsd
  init_hostname=${init_hostname:-${variant}-boxv0000}
  GUEST=${1:-${variant}-aarch64-${VOL_MGR}}

  ISO_PATH=${ISO_PATH:-$(find ${ISOS_PARDIR}/freebsd -name 'FreeBSD-*-aarch64-disc1.iso' | tail -n1)}
  (cd ${ISOS_PARDIR}/freebsd ; sha256sum --ignore-missing -c CHECKSUM.SHA256-FreeBSD-*-RELEASE*-aarch64)

  sleep 5 ; _freebsd ; _prep ; sleep 3 ; _install_aarch64
}
#----------------------------------------

_debian() {
  cfg_file=preseed.cfg ; service_mgr=${service_mgr:-sysvinit}
  #repo_host=${repo_host:-deb.debian.org} ; repo_directory=${repo_directory:-/debian}
  repo_host=${repo_host:-deb.devuan.org} ; repo_directory=${repo_directory:-/merged}

  #CFGHOST [http://<host>:<port> | file://]
  EXTRA_ARGS=${EXTRA_ARGS:- auto=true preseed/url=${CFGHOST:-http://10.0.2.1:8080}/${cfg_file} locale=en_US keymap=us console-setup/ask_detect=false domain= hostname=${init_hostname} mirror/http/hostname=${repo_host} mirror/http/directory=${repo_directory} choose-init/select_init=${service_mgr}}
  cp -a init/debian/${VOL_MGR}-preseed.cfg /tmp/${cfg_file}

  tar -cf /tmp/scripts.tar init/common init/debian -C scripts debian
  ## NOTE, debconf-get-selections [--installer] -> auto install cfg
}
debian_x86_64() {
  VOL_MGR=${VOL_MGR:-std} ; variant=debian
  init_hostname=${init_hostname:-${variant}-boxv0000}
  GUEST=${1:-${variant}-x86_64-${VOL_MGR}}

  #ISO_PATH=${ISO_PATH:-$(find ${ISOS_PARDIR}/debian -name 'debian-*-amd64-netinst.iso' | tail -n1)} ;
  ISO_PATH=${ISO_PATH:-$(find ${ISOS_PARDIR}/devuan -name 'devuan_*_amd64*netinstall.iso' | tail -n1)} ;
  if [ "$ISO_PATH" ] ; then
    #(cd ${ISOS_PARDIR}/debian ; sha256sum --ignore-missing -c SHA256SUMS) ;
    (cd ${ISOS_PARDIR}/devuan ; sha256sum --ignore-missing -c SHA256SUMS) ;
  fi

  ##MIRROR: pkgmaster.devuan.org/devuan
  ##dnld: <mirror>/dists/<version>/main/installer-amd64/current/images/cdrom/debian-installer/amd64/{linux,initrd.gz}
  KERNEL_PATH=${KERNEL_PATH:-$(find ${ISOS_PARDIR}/devuan -name 'linux' | tail -n1)}
  INITRD_PATH=${INITRD_PATH:-$(find ${ISOS_PARDIR}/devuan -name 'initrd.gz' | tail -n1)}

  sleep 5 ; _debian ; _prep ; sleep 3 ; _install_x86_64
}
debian_aarch64() {
  VOL_MGR=${VOL_MGR:-std} ; variant=debian
  init_hostname=${init_hostname:-${variant}-boxv0000}
  GUEST=${1:-${variant}-aarch64-${VOL_MGR}}

  #ISO_PATH=${ISO_PATH:-$(find ${ISOS_PARDIR}/debian/arm64 -name 'debian-*-arm64-netinst.iso' | tail -n1)} ;
  ISO_PATH=${ISO_PATH:-$(find ${ISOS_PARDIR}/devuan/arm64/netboot -name 'mini.iso' | tail -n1)} ;
  if [ "$ISO_PATH" ] ; then
    #(cd ${ISOS_PARDIR}/debian/arm64 ; sha256sum --ignore-missing -c SHA256SUMS) ;
    (cd ${ISOS_PARDIR}/devuan/arm64 ; sha256sum --ignore-missing -c SHA256SUMS) ;
  fi

  ##MIRROR: pkgmaster.devuan.org/devuan
  ##dnld: <mirror>/dists/<version>/main/installer-arm64/current/images/netboot/debian-installer/arm64/{linux,initrd.gz}
  KERNEL_PATH=${KERNEL_PATH:-$(find ${ISOS_PARDIR}/devuan/arm64/netboot/debian-installer/arm64 -name 'linux' | tail -n1)}
  INITRD_PATH=${INITRD_PATH:-$(find ${ISOS_PARDIR}/devuan/arm64/netboot/debian-installer/arm64 -name 'initrd.gz' | tail -n1)}

  echo '?? Unknown error - must enter grub command-line manually for reboots: '
  echo '#NOTE: (std) rootdev=/dev/vda5  OR  (lvm) rootdev=/dev/mapper/vg0-osRoot'
  echo '  linux (hd0,gpt3)/vmlinuz root=$rootdev resume=/dev/foo'
  echo '  initrd (hd0,gpt3)/initrd.img'
  echo '  boot'

  sleep 5 ; _debian ; _prep ; sleep 3 ; _install_aarch64
}
#----------------------------------------

_alpine() {
  INST_SRC_OPTS=${INST_SRC_OPTS:---cdrom="${ISO_PATH}"}

  tar -cf /tmp/scripts.tar init/common init/alpine -C scripts alpine

  echo "### Once network connected, transfer needed file(s) ###" ; sleep 5

  ##!! login user/passwd: root/-

  #ifconfig ; ifconfig {ifdev} up ; udhcpc -i {ifdev} ; cd /tmp

  ## NOTE, transfer [dir(s) | file(s)]: init/common, init/alpine

  #service sshd stop
  #export MIRROR=dl-cdn.alpinelinux.org/alpine
  #APKREPOSOPTS=http://${MIRROR}/latest-stable/main BOOT_SIZE=200 USE_EFI=1 [BOOTFS=ext4 VARFS=ext4] setup-alpine -f init/alpine/[std | lvm]-answers
  # .. reboot
  # .. after reboot
  #sh init/alpine/[std | lvm]-post_autoinstall.sh [$PASSWD_CRYPTED]
}
alpine_x86_64() {
  VOL_MGR=${VOL_MGR:-std} ; variant=alpine
  init_hostname=${init_hostname:-${variant}-boxv0000}
  GUEST=${1:-${variant}-x86_64-${VOL_MGR}}

  ISO_PATH=${ISO_PATH:-$(find ${ISOS_PARDIR}/alpine -name "alpine-extended-*-x86_64.iso" | tail -n1)} ;
  (cd ${ISOS_PARDIR}/alpine ; sha256sum --ignore-missing -c alpine-extended-*-x86_64.iso.sha256)

  sleep 5 ; _alpine ; _prep ; sleep 3 ; _install_x86_64
}
alpine_aarch64() {
  VOL_MGR=${VOL_MGR:-std} ; variant=alpine
  init_hostname=${init_hostname:-${variant}-boxv0000}
  GUEST=${1:-${variant}-aarch64-${VOL_MGR}}

  ISO_PATH=${ISO_PATH:-$(find ${ISOS_PARDIR}/alpine -name "alpine-standard-*-aarch64.iso" | tail -n1)}
  (cd ${ISOS_PARDIR}/alpine ; sha256sum --ignore-missing -c alpine-standard-*-aarch64.iso.sha256)

  sleep 5 ; _alpine ; _prep ; sleep 3 ; _install_aarch64
}
#----------------------------------------

_suse() {
  cfg_file=autoinst.xml
  repo_host=${repo_host:-download.opensuse.org} ; repo_directory=${repo_directory:-/distribution/openSUSE-current/repo/oss}

  #CFGHOST [http://<host>:<port> | file://]
  EXTRA_ARGS=${EXTRA_ARGS:- netsetup=dhcp lang=en_US install=http://${repo_host}${repo_directory} hostname=${init_hostname} domain= autoyast=${CFGHOST:-http://10.0.2.1:8080}/${cfg_file} textmode=1}
  cp -a init/suse/${VOL_MGR}-autoinst.xml /tmp/${cfg_file}

  tar -cf /tmp/scripts.tar init/common init/suse -C scripts suse
  ## NOTE, yast2 clone_system -> auto install config: /root/autoinst.xml
}
suse_x86_64() {
  VOL_MGR=${VOL_MGR:-std} ; variant=suse
  init_hostname=${init_hostname:-${variant}-boxv0000}
  GUEST=${1:-${variant}-x86_64-${VOL_MGR}}

  #ISO_PATH=${ISO_PATH:-$(find ${ISOS_PARDIR}/opensuse -name "openSUSE-Leap-*-NET-x86_64*.iso" | tail -n1)}
  ISO_PATH=${ISO_PATH:-$(find ${ISOS_PARDIR}/opensuse/live -name "GeckoLinux_*.x86_64*.iso" | tail -n1)}
  if [ "$ISO_PATH" ] ; then
    #(cd ${ISOS_PARDIR}/opensuse ; sha256sum --ignore-missing -c openSUSE-Leap-*-NET-x86_64*.iso.sha256) ;
    (cd ${ISOS_PARDIR}/opensuse/live ; sha256sum --ignore-missing -c GeckoLinux_*.x86_64*.iso.sha256) ;
  fi

  ##dnld: <mirror>/distribution/<version>/repo/oss/boot/x86_64/loader/{linux,initrd}
  KERNEL_PATH=${KERNEL_PATH:-$(find ${ISOS_PARDIR}/opensuse -name 'linux' | tail -n1)}
  INITRD_PATH=${INITRD_PATH:-$(find ${ISOS_PARDIR}/opensuse -name 'initrd' | tail -n1)}

  sleep 5 ; _suse ; _prep ; sleep 3 ; _install_x86_64
}
suse_aarch64() {
  VOL_MGR=${VOL_MGR:-std} ; variant=suse
  init_hostname=${init_hostname:-${variant}-boxv0000}
  GUEST=${1:-${variant}-aarch64-${VOL_MGR}}

  ISO_PATH=${ISO_PATH:-$(find ${ISOS_PARDIR}/opensuse/aarch64 -name "openSUSE-Leap-*-NET-aarch64*.iso" | tail -n1)}
  if [ "$ISO_PATH" ] ; then
    (cd ${ISOS_PARDIR}/opensuse/aarch64 ; sha256sum --ignore-missing -c openSUSE-Leap-*-NET-aarch64*.iso.sha256) ;
  fi

  ##dnld: <mirror>/distribution/<version>/repo/oss/boot/aarch64/loader/{linux,initrd}
  KERNEL_PATH=${KERNEL_PATH:-$(find ${ISOS_PARDIR}/opensuse/aarch64 -name 'linux' | tail -n1)}
  INITRD_PATH=${INITRD_PATH:-$(find ${ISOS_PARDIR}/opensuse/aarch64 -name 'initrd' | tail -n1)}

  sleep 5 ; _suse ; _prep ; sleep 3 ; _install_aarch64
}
#----------------------------------------

_redhat() {
  cfg_file=anaconda-ks.cfg
  # [rocky/9|almalinux/9|centos/9-stream]/BaseOS/x86_64/os | centos/7/os/x86_64]
  repo_host=${repo_host:-dl.rockylinux.org/pub/rocky}
  #repo_host=${repo_host:-repo.almalinux.org/almalinux}
  #repo_host=${repo_host:-mirror.centos.org/centos}

  #CFGHOST [http://<host>:<port> | file://]
  EXTRA_ARGS=${EXTRA_ARGS:- nomodeset video=1024x768 inst.ks=${CFGHOST:-http://10.0.2.1:8080}/${cfg_file} inst.repo=http://${repo_host}${repo_directory} ip=::::${init_hostname}::dhcp inst.selinux=1 inst.enforcing=0 inst.text}
  # systemd.unit=multi-user.target
  cp -a init/redhat/${VOL_MGR}-anaconda-ks.cfg /tmp/${cfg_file}

  tar -cf /tmp/scripts.tar init/common init/redhat -C scripts redhat
  ## NOTE, saved auto install config: /root/anaconda-ks.cfg

  ## NOTE, in kickstart failure to find ks.cfg:
  ##  Alt-Tab to cmdline
  ##  anaconda --kickstart <path>/anaconda-ks.cfg
}
redhat_x86_64() {
  VOL_MGR=${VOL_MGR:-std} ; variant=redhat
  init_hostname=${init_hostname:-${variant}-boxv0000} ; RELEASE=${RELEASE:-9}
  repo_directory=${repo_directory:-/${RELEASE}/BaseOS/x86_64/os}
  GUEST=${1:-${variant}-x86_64-${VOL_MGR}}

  ISO_PATH=${ISO_PATH:-$(find ${ISOS_PARDIR}/rocky -name "Rocky-*-x86_64*-boot.iso" | tail -n1)}
  #ISO_PATH=${ISO_PATH:-$(find ${ISOS_PARDIR}/almalinux -name "AlmaLinux-*-x86_64*-boot.iso" | tail -n1)}
  #ISO_PATH=${ISO_PATH:-$(find ${ISOS_PARDIR}/centos -name "CentOS-*-x86_64*-boot.iso" | tail -n1)}
  if [ "$ISO_PATH" ] ; then
    (cd ${ISOS_PARDIR}/rocky ; sha256sum --ignore-missing -c CHECKSUM) ;
    #(cd ${ISOS_PARDIR}/almalinux ; sha256sum --ignore-missing -c CHECKSUM) ;
    #(cd ${ISOS_PARDIR}/centos ; sha256sum --ignore-missing -c CHECKSUM) ;
  fi

  ##dnld: <mirror>/<version>/BaseOS/x86_64/kickstart/images/pxeboot/{vmlinuz,initrd.img}
  KERNEL_PATH=${KERNEL_PATH:-$(find ${ISOS_PARDIR}/rocky -name 'vmlinuz' | tail -n1)}
  INITRD_PATH=${INITRD_PATH:-$(find ${ISOS_PARDIR}/rocky -name 'initrd.img' | tail -n1)}

  sleep 5 ; _redhat ; _prep ; sleep 3 ; _install_x86_64
}
redhat_aarch64() {
  VOL_MGR=${VOL_MGR:-std} ; variant=redhat
  init_hostname=${init_hostname:-${variant}-boxv0000} ; RELEASE=${RELEASE:-9}
  repo_directory=${repo_directory:-/${RELEASE}/BaseOS/aarch64/os}
  GUEST=${1:-${variant}-aarch64-${VOL_MGR}}

  ISO_PATH=${ISO_PATH:-$(find ${ISOS_PARDIR}/rocky/aarch64 -name "Rocky-*-aarch64*-boot.iso" | tail -n1)}
  #ISO_PATH=${ISO_PATH:-$(find ${ISOS_PARDIR}/almalinux/aarch64 -name "AlmaLinux-*-aarch64*-boot.iso" | tail -n1)}
  #ISO_PATH=${ISO_PATH:-$(find ${ISOS_PARDIR}/centos/aarch64 -name "CentOS-*-aarch64*-boot.iso" | tail -n1)}
  if [ "$ISO_PATH" ] ; then
    (cd ${ISOS_PARDIR}/rocky/aarch64 ; sha256sum --ignore-missing -c CHECKSUM) ;
    #(cd ${ISOS_PARDIR}/almalinux/aarch64 ; sha256sum --ignore-missing -c CHECKSUM) ;
    #(cd ${ISOS_PARDIR}/centos/aarch64 ; sha256sum --ignore-missing -c CHECKSUM) ;
  fi

  ##dnld: <mirror>/<version>/BaseOS/aarch64/kickstart/images/pxeboot/{vmlinuz,initrd.img}
  KERNEL_PATH=${KERNEL_PATH:-$(find ${ISOS_PARDIR}/rocky -name 'vmlinuz' | tail -n1)}
  INITRD_PATH=${INITRD_PATH:-$(find ${ISOS_PARDIR}/rocky -name 'initrd.img' | tail -n1)}

  sleep 5 ; _redhat ; _prep ; sleep 3 ; _install_aarch64
}
#----------------------------------------

mageia_x86_64() {
  VOL_MGR=${VOL_MGR:-std} ; variant=mageia
  cfg_file=auto_inst_cfg.pl
  repo_host=${repo_host:-mirrors.kernel.org/mageia}

  #CFGHOST [http://<host>:<port> | file://]
  EXTRA_ARGS=${EXTRA_ARGS:- automatic=method:http,server:${repo_host},directory:${repo_directory},network:dhcp auto_install=${CFGHOST:-http://10.0.2.1:8080}/${cfg_file} nomodeset text}
  # systemd.unit=multi-user.target
  cp -a init/mageia/${VOL_MGR}-auto_inst.cfg.pl /tmp/${cfg_file}

  tar -cf /tmp/scripts.tar init/common init/mageia -C scripts mageia
  ## NOTE, saved auto install config: /root/drakx/auto_inst_cfg.pl

  init_hostname=${init_hostname:-${variant}-boxv0000} ; RELEASE=${RELEASE:-8}
  repo_directory=${repo_directory:-/distrib/${RELEASE}/x86_64}
  GUEST=${1:-${variant}-x86_64-${VOL_MGR}}

  ISO_PATH=${ISO_PATH:-$(find ${ISOS_PARDIR}/mageia -maxdepth 1 -name "Mageia-*-x86_64*.iso" | tail -n1)}
  if [ "$ISO_PATH" ] ; then
  	(cd ${ISOS_PARDIR}/mageia ; sha512sum --ignore-missing -c Mageia-*-x86_64*.iso.sha512) ;
  fi

  ##dnld: <mirror>/distrib/<version>/x86_64/isolinux/x86_64/{vmlinuz,all.rdz}
  KERNEL_PATH=${KERNEL_PATH:-$(find ${ISOS_PARDIR}/mageia -name 'vmlinuz' | tail -n1)}
  INITRD_PATH=${INITRD_PATH:-$(find ${ISOS_PARDIR}/mageia -name 'all.rdz' | tail -n1)}

  sleep 5 ; _prep ; sleep 3 ; _install_x86_64
}
#----------------------------------------

_openbsd() {
  INST_SRC_OPTS=${INST_SRC_OPTS:---import --disk="${ISO_PATH}"}

  tar -cf /tmp/scripts.tar init/common init/openbsd -C scripts openbsd
  ## NOTE, saved install response file: /tmp/i/install.resp

  echo "### Once network connected, transfer needed file(s) ###" ; sleep 5

  ##NOTE, enter shell: S
  ##!! login user/passwd: root/-

  #ifconfig ; dhclient {ifdev}

  ## NOTE, transfer [dir(s) | file(s)]: init/common, init/openbsd

  #export MIRROR=ftp4.usa.openbsd.org/pub/OpenBSD
  #cp -a init/openbsd/custom.disklabel init/openbsd/install.resp /tmp/
  #sh init/openbsd/autoinstall.sh [$PASSWD_PLAIN]
}
openbsd_x86_64() {
  VOL_MGR=${VOL_MGR:-std} ; variant=openbsd
  init_hostname=${init_hostname:-${variant}-boxv0000}
  GUEST=${1:-${variant}-x86_64-${VOL_MGR}}

  ## ?? --boot uefi NOT WORKING for iso ??
  #QUEFI_OPTS=" "
  #VUEFI_OPTS=" "

  ISO_PATH=${ISO_PATH:-$(find ${ISOS_PARDIR}/openbsd/amd64 -name 'install*.img' | tail -n1)} ;
  (cd ${ISOS_PARDIR}/openbsd/amd64 ; sha256sum --ignore-missing -c SHA256) ;

  sleep 5 ; _openbsd ; _prep
  qemu-img convert -O qcow2 ${ISO_PATH} ${OUT_DIR}/${GUEST}.qcow2
  qemu-img resize -f qcow2 ${OUT_DIR}/${GUEST}.qcow2 30720M
  sleep 3 ; _install_x86_64
}
openbsd_aarch64() {
  CDROM_OPT=${CDROM_OPT:-" "}
  VOL_MGR=${VOL_MGR:-std} ; variant=openbsd
  init_hostname=${init_hostname:-${variant}-boxv0000}
  GUEST=${1:-${variant}-aarch64-${VOL_MGR}}

  ISO_PATH=${ISO_PATH:-$(find ${ISOS_PARDIR}/openbsd/arm64 -name 'install*.img' | tail -n1)} ;
  (cd ${ISOS_PARDIR}/openbsd/arm64 ; sha256sum --ignore-missing -c SHA256) ;

  sleep 5 ; _openbsd ; _prep
  qemu-img convert -O qcow2 ${ISO_PATH} ${OUT_DIR}/${GUEST}.qcow2
  qemu-img resize -f qcow2 ${OUT_DIR}/${GUEST}.qcow2 30720M
  sleep 3 ; _install_aarch64
}

#----------------------------------------
${@:-freebsd_x86_64 freebsd-x86_64-std}
