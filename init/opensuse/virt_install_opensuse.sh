OS_VARIANT=${OS_VARIANT:-opensuse-unknown} ; VM_NAME=${VM_NAME:-opensuse-Stable-init}

INITRD_INJECT_OPTS=${INITRD_INJECT_OPTS:-"--initrd-inject=/tmp/autoinst.xml"}
EXTRA_ARGS_OPTS=${EXTRA_ARGS_OPTS:-"--extra-args='netsetup=dhcp lang=en_US hostname=opensuse-boxv0000 domain= autoyast=file:///autoinst.xml textmode=1 install=http://'"}
INST_SRC_OPTS=${INST_SRC_OPTS:-"--location=http://mirror.math.princeton.edu/pub/opensuse-full/opensuse/distribution/openSUSE-stable/repo/oss"}
#INST_SRC_OPTS=${INST_SRC_OPTS:-"--cdrom=/mnt/Data0/distros/fixed/opensuse/openSUSE-Leap-42.1-NET-x86_64.iso"}

cp init/opensuse/ext4-autoinst.xml /tmp/autoinst.xml
qemu-img create -f qcow2 /mnt/Data1/Virtual_Machs/vm_prac/${VM_NAME}.qcow2 30720M

virt-install --connect qemu:///system --virt-type kvm --machine q35 --video qxl --controller virtio-serial --console pty,target_type=serial --graphics vnc,port=-1 --memory 1536 --vcpus 2 --network network=default,model=virtio-net --boot menu=on,uefi,cdrom,hd,network --boot loader=/usr/share/OVMF/OVMF_CODE.fd --controller scsi,model=virtio-scsi --disk bus=scsi,path=/mnt/Data1/Virtual_Machs/vm_prac/${VM_NAME}.qcow2,cache=writeback,discard=unmap,format=qcow2 -n ${VM_NAME} --os-variant ${OS_VARIANT} ${INITRD_INJECT_OPTS} "${EXTRA_ARGS_OPTS}" ${INST_SRC_OPTS}
