#!/bin/sh -x

# usage:
#   sh vmrun.sh import_[qemu | lxc] [GUEST]
#   sh vmrun.sh run_virsh [GUEST]
#   or
#   sh vmrun.sh run_qemu [GUEST]
#
# example ([defaults]):
#   sh vmrun.sh run_qemu [freebsd-Release-zfs]

STORAGE_DIR=${STORAGE_DIR:-$(dirname $0)} ; IMGEXT=${IMGEXT:-.qcow2}

#-------- create Vagrant ; use box image --------
box_vagrant() {
  GUEST=${1:-freebsd-Release-zfs} ; IMGFILE=${IMGFILE:-${GUEST}${IMGEXT}}
  author=${author:-thebridge0491} ; datestamp=${datestamp:-`date +"%Y.%m.%d"`}
  if [ ! -e ${STORAGE_DIR}/metadata.json ] ; then
    echo '{"provider":"libvirt","virtual_size":30,"format":"qcow2"}' > \
      ${STORAGE_DIR}/metadata.json ;
  fi
  if [ ! -e ${STORAGE_DIR}/info.json ] ; then
    cat << EOF > ${STORAGE_DIR}/info.json ;
{
 "Author": "${author} <${author}-codelab@yahoo.com>",
 "Repository": "https://bitbucket.org/${author}/vm_templates_sh.git",
 "Description": "Virtual machine templates (KVM/QEMU hybrid boot: BIOS+UEFI) using auto install methods and/or chroot install scripts"
}
EOF
  fi
  if [ ! -e ${STORAGE_DIR}/Vagrantfile ] ; then
    cat << EOF > ${STORAGE_DIR}/Vagrantfile ;

## minimal contents
#Vagrant.configure("2") do |config|
#  config.vm.provider :libvirt do |libvirt|
#    libvirt.driver = 'kvm'
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
    p.loader = '/usr/share/OVMF/OVMF_CODE.fd'
  end
end
EOF
  fi
  #mv ${STORAGE_DIR}/${IMGFILE} ${STORAGE_DIR}/box.img
  qemu-img convert -f qcow2 -O qcow2 ${STORAGE_DIR}/${IMGFILE} ${STORAGE_DIR}/box.img
  (cd ${STORAGE_DIR} ; tar -cvzf ${GUEST}-${datestamp}.libvirt.box metadata.json info.json Vagrantfile `ls vmrun*` OVMF_CODE.fd box.img)

  #pystache ${STORAGE_DIR}/catalog.json.mustache "{
  #  \"author\":\"${author}\",
  #  \"guest\":\"${GUEST}\",
  #  \"datestamp\":\"${datestamp}\"
  #}" > ${STORAGE_DIR}/${GUEST}_catalog.json
#  cat << EOF >> mustache - ${STORAGE_DIR}/catalog.json.mustache > ${STORAGE_DIR}/${GUEST}_catalog.json
#---
#author: ${author}
#guest: ${GUEST}
#datestamp: ${datestamp}
#---
#EOF
  erb author=${author} guest=${GUEST} datestamp=${datestamp} \
    ${STORAGE_DIR}/catalog.json.erb > ${STORAGE_DIR}/${GUEST}_catalog.json
}

diff_boximage() {
  GUEST=${1:-freebsd-Release-zfs} ; BOXPREFIX=${BOXPREFIX:-${GUEST}}
  qemu-img create -f qcow2 -o backing_file=$(cd ${STORAGE_DIR} ; find ${BOXPREFIX}*libvirt.box -name box.img | tail -n1) \
    ${STORAGE_DIR}/${GUEST}${IMGEXT}
  echo ''
  qemu-img info --backing-chain ${STORAGE_DIR}/${GUEST}${IMGEXT} ; sleep 5
}

revert_backingimage() {
  GUEST=${1:-freebsd-Release-zfs} ; BOXPREFIX=${BOXPREFIX:-${GUEST}}
  backing_file=$(cd ${STORAGE_DIR} ; qemu-img info --backing-chain ${GUEST}${IMGEXT} | sed -n 's|backing file:[ ]*\(.*\)$|\1|p')
  mv ${STORAGE_DIR}/${GUEST}${IMGEXT} ${STORAGE_DIR}/${GUEST}${IMGEXT}.bak
  sync ; (cd ${STORAGE_DIR} ; cp ${backing_file} ${GUEST}${IMGEXT}) ; sync
  (cd ${STORAGE_DIR} ; qemu-img rebase -b ${GUEST}${IMGEXT} \
    ${STORAGE_DIR}/${GUEST}${IMGEXT}.bak ; sync)
  qemu-img commit ${STORAGE_DIR}/${GUEST}${IMGEXT}.bak ; sync
  rm ${STORAGE_DIR}/${GUEST}${IMGEXT}.bak ; sync
  qemu-img info --backing-chain ${STORAGE_DIR}/${GUEST}${IMGEXT} ; sleep 5
}
#------------------------------------------------

#-------------- using virtinst ------------------
import_lxc() {
  GUEST=${1:-devuan-boxe0000}
  CONNECT_OPT=${CONNECT_OPT:---connect lxc:///}

  virt-install ${CONNECT_OPT} --init /sbin/init --memory 768 --vcpus 1 \
    --controller virtio-serial --console pty,target_type=virtio \
    --network network=default,model=virtio-net,mac=RANDOM --boot menu=on \
    ${VIRTFS_OPTS:---filesystem type=mount,mode=passthrough,source=/mnt/Data0,target=9p_Data0} \
    --filesystem $HOME/.local/share/lxc/${GUEST}/rootfs,/ -n ${GUEST} &

  sleep 10 ; virsh ${CONNECT_OPT} ttyconsole ${GUEST}
  #sleep 5 ; virsh ${CONNECT_OPT} dumpxml ${GUEST} > $HOME/.local/share/lxc/${GUEST}.xml
}

import_qemu() {
  GUEST=${1:-freebsd-Release-zfs} ; IMGFILE=${IMGFILE:-${GUEST}${IMGEXT}}
  CONNECT_OPT=${CONNECT_OPT:---connect qemu:///system}
  VUEFI_OPTS=${VUEFI_OPTS:---boot uefi}

  virt-install ${CONNECT_OPT} --memory 2048 --vcpus 2 \
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
  GUEST=${1:-freebsd-Release-zfs}
  CONNECT_OPT=${CONNECT_OPT:---connect qemu:///system}

  ## NOTE, to convert qemu-system args to libvirt domain XML:
  #  eval "echo \"$(< vmrun_qemu.args)\"" > /tmp/run_qemu.args
  #  virsh ${CONNECT_OPT} domxml-from-native qemu-argv /tmp/run_qemu.args

  virsh ${CONNECT_OPT} start ${GUEST}
  sleep 10 ; virsh ${CONNECT_OPT} vncdisplay ${GUEST} ; sleep 5
  virt-viewer ${CONNECT_OPT} ${GUEST} &
}
#------------------------------------------------

#------------ using qemu-system-* ---------------
run_qemu() {
  GUEST=${1:-freebsd-Release-zfs} ; IMGFILE=${IMGFILE:-${GUEST}${IMGEXT}}
  QUEFI_OPTS=${QUEFI_OPTS:-"-smbios type=0,uefi=on -bios ${STORAGE_DIR}/OVMF_CODE.fd"}
  qemu-system-x86_64 -machine q35,accel=kvm:hvf:tcg -smp cpus=2 -m size=2048 \
    -global PIIX4_PM.disable_s3=1 -global PIIX4_PM.disable_s4=1 \
    -display default,show-cursor=on -boot order=cd,menu=on -usb \
    -net nic,model=virtio-net-pci,macaddr=52:54:00:$(openssl rand -hex 3 | sed 's|\(..\)|\1:|g; s|:$||') \
    ${NET_OPTS:--net bridge,br=br0} \
    ${VIRTFS_OPTS:--virtfs local,id=fsdev0,path=/mnt/Data0,mount_tag=9p_Data0,security_model=passthrough} \
    -device virtio-scsi-pci,id=scsi0 -device scsi-hd,drive=hd0 \
    -drive file=${STORAGE_DIR}/${IMGFILE},cache=writeback,discard=unmap,detect-zeroes=unmap,if=none,id=hd0,format=qcow2 \
    ${QUEFI_OPTS} -name ${GUEST} &
}
#------------------------------------------------

#------------------------------------------------
${@:-run_qemu freebsd-Release-zfs}
