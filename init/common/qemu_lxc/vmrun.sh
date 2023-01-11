#!/bin/sh -x

# usage:
#   [MACHINE=x86_64] sh vmrun.sh import_[qemu | lxc] [GUEST]
#   sh vmrun.sh run_virsh [GUEST]
#   or
#   [MACHINE=x86_64] sh vmrun.sh run_qemu [GUEST]
#   or
#   sh vmrun.sh run_bhyve [GUEST]
#
# example ([defaults]):
#   [MACHINE=x86_64] sh vmrun.sh run_qemu [freebsd-x86_64-zfs]

STORAGE_DIR=${STORAGE_DIR:-$(dirname $0)} ; IMGFMT=${IMGFMT:-qcow2}
MACHINE=${MACHINE:-x86_64} ; IMGEXT=${IMGEXT:-.qcow2}
FIRMWARE_BHYVE_X64=${FIRMWARE_BHYVE_X64:-/usr/local/share/uefi-firmware/BHYVE_UEFI_CODE.fd}
FIRMWARE_QEMU_X64=${FIRMWARE_QEMU_X64:-/usr/share/OVMF/OVMF_CODE.fd}
FIRMWARE_QEMU_AA64=${FIRMWARE_QEMU_AA64:-/usr/share/AAVMF/AAVMF_CODE.fd}

#mac_last3=$(hexdump -n3 -e '/1 ":%02x"' /dev/random | cut -c2-)
#mac_last3=$(od -N3 -tx1 -An /dev/random | awk '$1=$1' | tr ' ' :)
mac_last3=$(openssl rand -hex 3 | sed 's|\(..\)|\1:|g; s|:$||')

#-------- create Vagrant ; use box image --------
box_vagrant() {
  GUEST=${1:-freebsd-${MACHINE}-zfs} ; PROVIDER=${PROVIDER:-libvirt}
  author=${author:-thebridge0491} ; build_timestamp=${build_timestamp:-`date +"%Y.%m"`}
  if [ ! -e ${STORAGE_DIR}/metadata.json ] ; then
    if [ "libvirt" = "${PROVIDER}" ] ; then
      echo '{"provider":"libvirt","virtual_size":30,"format":"qcow2"}' > \
        ${STORAGE_DIR}/metadata.json ;
    elif [ "bhyve" = "${PROVIDER}" ] ; then
      echo '{"provider":"bhyve","virtual_size":30,"format":"raw"}' > \
        ${STORAGE_DIR}/metadata.json ;
    fi ;
  fi
  if [ ! -e ${STORAGE_DIR}/info.json ] ; then
    cat << EOF > ${STORAGE_DIR}/info.json ;
{
 "Author": "${author} <${author}-codelab@yahoo.com>",
 "Repository": "https://bitbucket.org/${author}/vm_templates_sh.git",
 "Description": "Virtual machine templates (QEMU x86_64[, aarch64]) using auto install methods and/or chroot install scripts"
}
EOF
  fi
  if [ ! -e ${STORAGE_DIR}/Vagrantfile ] ; then
    if [ "libvirt" = "${PROVIDER}" ] ; then
        cat << EOF > ${STORAGE_DIR}/Vagrantfile ;

## minimal contents
#Vagrant.configure("2") do |config|
#  config.vm.provider :libvirt do |p|
#    p.driver = 'kvm'
#  end
#end

# custom contents
# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure(2) do |config|

  config.ssh.shell = 'sh'
  config.vm.boot_timeout = 1800
  config.vm.synced_folder '.', '/vagrant', disabled: true

  config.vm.provider :libvirt do |p, override|
    p.driver = 'kvm'
    p.cpus = 2
    p.memory = 2048
    p.video_vram = 64
    p.video_type = 'qxl'
    p.disk_bus = 'virtio'
    p.nic_model_type = 'virtio'
  end
end
EOF
    elif [ "bhyve" = "${PROVIDER}" ] ; then
        cat << EOF > ${STORAGE_DIR}/Vagrantfile ;

## minimal contents
#Vagrant.configure("2") do |config|
#  config.vm.provider :bhyve do |p|
#    p.cpus = 1
#    p.memory = 1024
#  end
#end

# custom contents
# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure(2) do |config|

  config.ssh.shell = 'sh'
  config.vm.boot_timeout = 1800
  config.vm.synced_folder '.', '/vagrant', disabled: true

  config.vm.provider :bhyve do |p, override|
    p.cpus = 2
    p.memory = 2048
  end
end
EOF
    fi
  fi
  if [ "libvirt" = "${PROVIDER}" ] ; then
    IMGFILE=${IMGFILE:-${GUEST}${IMGEXT}} ;
    #mv ${STORAGE_DIR}/${IMGFILE} ${STORAGE_DIR}/box.img ;
    qemu-img convert -f qcow2 -O qcow2 ${STORAGE_DIR}/${IMGFILE} \
      ${STORAGE_DIR}/box.img ;
    if [ "aarch64" = "${MACHINE}" ] ; then
      cp -a ${FIRMWARE_QEMU_AA64} ${STORAGE_DIR}/ ;
    else
      cp -a ${FIRMWARE_QEMU_X64} ${STORAGE_DIR}/ ;
    fi ;
  elif [ "bhyve" = "${PROVIDER}" ] ; then
    IMGFILE=${IMGFILE:-${GUEST}.raw}
    mv ${STORAGE_DIR}/${IMGFILE} ${STORAGE_DIR}/box.img ;
    cp -a ${FIRMWARE_BHYVE_X64} ${STORAGE_DIR}/ ;
  fi
  (cd ${STORAGE_DIR} ; tar -cvzf ${GUEST}-${build_timestamp}.${PROVIDER}.box metadata.json info.json Vagrantfile `ls vmrun* *_CODE.fd` box.img)

  if command -v erb > /dev/null ; then
    erb author=${author} guest=${GUEST} datestamp=${build_timestamp} \
      ${STORAGE_DIR}/catalog.json.erb > ${STORAGE_DIR}/${GUEST}_catalog.json ;
  elif command -v chevron > /dev/null ; then
    echo "{
      \"author\":\"${author}\",
      \"guest\":\"${GUEST}\",
      \"datestamp\":\"${build_timestamp}\"
    }" | chevron -d /dev/stdin ${STORAGE_DIR}/catalog.json.mustache > ${STORAGE_DIR}/${GUEST}_catalog.json ;
  elif command -v pystache > /dev/null ; then
    pystache ${STORAGE_DIR}/catalog.json.mustache "{
      \"author\":\"${author}\",
      \"guest\":\"${GUEST}\",
      \"datestamp\":\"${build_timestamp}\"
    }" > ${STORAGE_DIR}/${GUEST}_catalog.json ;
  elif command -v mustache > /dev/null ; then
    cat << EOF >> mustache - ${STORAGE_DIR}/catalog.json.mustache > ${STORAGE_DIR}/${GUEST}_catalog.json ;
---
author: ${author}
guest: ${GUEST}
datestamp: ${build_timestamp}
---
EOF
  fi
}

diff_qemuimage() {
  GUEST=${1:-freebsd-${MACHINE}-zfs} ; BOXPREFIX=${BOXPREFIX:-${GUEST}*/}
  qemu-img create -f qcow2 -F qcow2 -o backing_file=$(cd ${STORAGE_DIR} ; find ${BOXPREFIX} -path "*${IMGEXT}" | tail -n1) \
    ${STORAGE_DIR}/${GUEST}${IMGEXT}
  echo ''
  qemu-img info --backing-chain ${STORAGE_DIR}/${GUEST}${IMGEXT} ; sleep 5
}

revert_backingimage() {
  GUEST=${1:-freebsd-${MACHINE}-zfs} ; BOXPREFIX=${BOXPREFIX:-${GUEST}}
  backing_file=$(cd ${STORAGE_DIR} ; qemu-img info --backing-chain ${GUEST}${IMGEXT} | sed -n 's|backing file:[ ]*\(.*\)$|\1|p')
  mv ${STORAGE_DIR}/${GUEST}${IMGEXT} ${STORAGE_DIR}/${GUEST}${IMGEXT}.bak
  sync ; (cd ${STORAGE_DIR} ; cp ${backing_file} ${GUEST}${IMGEXT}) ; sync
  (cd ${STORAGE_DIR} ; qemu-img rebase -F qcow2 -b ${GUEST}${IMGEXT} \
    ${STORAGE_DIR}/${GUEST}${IMGEXT}.bak ; sync)
  qemu-img commit ${STORAGE_DIR}/${GUEST}${IMGEXT}.bak ; sync
  rm ${STORAGE_DIR}/${GUEST}${IMGEXT}.bak ; sync
  qemu-img info --backing-chain ${STORAGE_DIR}/${GUEST}${IMGEXT} ; sleep 5
}
#------------------------------------------------

#-------------- using virtinst ------------------
import_lxc() {
  GUEST=${1:-debian-boxe0000}
  CONNECT_OPT=${CONNECT_OPT:---connect lxc:///}

  virt-install ${CONNECT_OPT} --init /sbin/init --cpu SandyBridge \
    --memory 768 --vcpus 1 \
    --controller virtio-serial --console pty,target_type=virtio \
    --network network=default,model=virtio-net,mac=RANDOM --boot menu=on \
    ${VIRTFS_OPTS:---filesystem type=mount,mode=passthrough,source=/mnt/Data0,target=9p_Data0} \
    --filesystem $HOME/.local/share/lxc/${GUEST}/rootfs,/ -n ${GUEST} &

  sleep 10 ; virsh ${CONNECT_OPT} ttyconsole ${GUEST}
  #sleep 5 ; virsh ${CONNECT_OPT} dumpxml ${GUEST} > $HOME/.local/share/lxc/${GUEST}.xml
}

import_qemu() {
  GUEST=${1:-freebsd-${MACHINE}-zfs} ; IMGFILE=${IMGFILE:-${GUEST}${IMGEXT}}
  CONNECT_OPT=${CONNECT_OPT:---connect qemu:///system}
  VUEFI_OPTS=${VUEFI_OPTS:---boot uefi}

  virt-install ${CONNECT_OPT} --arch ${MACHINE} --cpu SandyBridge \
    --memory 2048 --vcpus 2 \
    --controller usb,model=ehci --controller virtio-serial \
    --console pty,target_type=virtio --graphics vnc,port=-1 \
    --network network=default,model=virtio-net,mac=RANDOM \
    --boot menu=on,cdrom,hd --controller scsi,model=virtio-scsi \
    ${VIRTFS_OPTS:---filesystem type=mount,mode=passthrough,source=/mnt/Data0,target=9p_Data0} \
    --disk path=${STORAGE_DIR}/${IMGFILE},cache=writeback,discard=unmap,detect_zeroes=unmap,bus=scsi \
    ${VUEFI_OPTS} -n ${GUEST} --import &

  sleep 30 ; virsh ${CONNECT_OPT} vncdisplay ${GUEST}
  #sleep 5 ; virsh ${CONNECT_OPT} dumpxml ${GUEST} > ${STORAGE_DIR}/${GUEST}.xml
}

run_virsh() {
  GUEST=${1:-freebsd-${MACHINE}-zfs}
  CONNECT_OPT=${CONNECT_OPT:---connect qemu:///system}

  ## NOTE, to convert qemu-system args to libvirt domain XML:
  #  eval "echo \"$(< vmrun_qemu.args)\"" > /tmp/run_qemu.args
  #  virsh ${CONNECT_OPT} domxml-from-native qemu-argv /tmp/run_qemu.args

  virsh ${CONNECT_OPT} start ${GUEST}
  sleep 10 ; virsh ${CONNECT_OPT} vncdisplay ${GUEST} ; sleep 5
  virt-viewer ${CONNECT_OPT} ${GUEST} &
}
#------------------------------------------------

#---------------- using bhyve -------------------
run_bhyve() {
  printf "%40s\n" | tr ' ' '#'
  echo '### Warning: FreeBSD bhyve currently requires root/sudo permission ###'
  printf "%40s\n\n" | tr ' ' '#' ; sleep 5

  GUEST=${1:-freebsd-${MACHINE}-zfs} ; IMGFILE=${IMGFILE:-${GUEST}.raw}
  BUEFI_OPTS=${BUEFI_OPTS:--s 29,fbuf,tcp=0.0.0.0:${VNCPORT:-5901},w=1024,h=768 \
    -s 30,xhci,tablet -l bootrom,${FIRMWARE_BHYVE_X64}}

  bhyve -A -H -P -c 2 -m 2048M -l com1,stdio -s 0,hostbridge -s 1,lpc \
    -s 2,virtio-net,${NET_OPT:-tap0},mac=52:54:00:${mac_last3} \
    -s 3,virtio-blk,${STORAGE_DIR}/${IMGFILE} \
    ${BUEFI_OPTS} ${VIRTFS_OPTS:--s 4,virtio-9p,9p_Data0=/mnt/Data0} \
    ${GUEST} &

  vncviewer :${VNCPORT:-5901} &

  #ls -al /dev/vmm # list running VMs
  #bhyvectl --destroy --vm=${GUEST}
}
#------------------------------------------------

#------------ using qemu-system-* ---------------
run_qemu() {
  GUEST=${1:-freebsd-${MACHINE}-zfs} ; IMGFILE=${IMGFILE:-${GUEST}${IMGEXT}}
  VIRTFS_OPTS=${VIRTFS_OPTS:--virtfs local,id=fsdev0,path=/mnt/Data0,mount_tag=9p_Data0,security_model=passthrough}

  if [ "aarch64" = "${MACHINE}" ] ; then
    QUEFI_OPTS=${QUEFI_OPTS:-"-smbios type=0,uefi=on -bios ${FIRMWARE_QEMU_AA64}"}
    qemu-system-aarch64 -cpu cortex-a57 -machine virt,gic-version=3,accel=kvm:hvf:tcg \
      -smp cpus=2 -m size=2048 -boot order=cd,menu=on -name ${GUEST} \
      -nic ${NET_OPT:-bridge,br=br0},id=net0,model=virtio-net-pci,mac=52:54:00:${mac_last3} \
      -device qemu-xhci,id=usb -usb -device usb-kbd -device usb-tablet \
      -device virtio-blk-pci,drive=hd0 \
      -drive file=${STORAGE_DIR}/${IMGFILE},cache=writeback,discard=unmap,detect-zeroes=unmap,if=none,id=hd0,format=${IMGFMT} \
      -display default,show-cursor=on -vga none -device virtio-gpu-pci \
      ${QUEFI_OPTS} ${VIRTFS_OPTS} &
  else
    QUEFI_OPTS=${QUEFI_OPTS:-"-smbios type=0,uefi=on -bios ${FIRMWARE_QEMU_X64}"}
    qemu-system-x86_64 -cpu SandyBridge -machine q35,accel=kvm:hvf:tcg \
      -global PIIX4_PM.disable_s3=1 -global PIIX4_PM.disable_s4=1 \
      -smp cpus=2 -m size=2048 -boot order=cd,menu=on -name ${GUEST} \
      -nic ${NET_OPT:-bridge,br=br0},id=net0,model=virtio-net-pci,mac=52:54:00:${mac_last3} \
      -device qemu-xhci,id=usb -usb -device usb-kbd -device usb-tablet \
      -device virtio-scsi-pci,id=scsi0 -device scsi-hd,drive=hd0 \
      -drive file=${STORAGE_DIR}/${IMGFILE},cache=writeback,discard=unmap,detect-zeroes=unmap,if=none,id=hd0,format=${IMGFMT} \
      -display default,show-cursor=on -vga none -device qxl-vga,vgamem_mb=64 \
      ${QUEFI_OPTS} ${VIRTFS_OPTS} &
  fi
}
#------------------------------------------------

#------------------------------------------------
${@:-run_qemu freebsd-x86_64-zfs}
