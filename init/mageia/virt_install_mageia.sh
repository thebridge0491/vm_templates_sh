OS_VARIANT=${OS_VARIANT:-mageia5} ; VM_NAME=${VM_NAME:-mageia-Release-init}

INITRD_INJECT_OPTS=${INITRD_INJECT_OPTS:-"--initrd-inject=/tmp/auto_inst.cfg.pl"}
EXTRA_ARGS_OPTS=${EXTRA_ARGS_OPTS:-"--extra-args='automatic=method:http,network:dhcp auto_install=auto_inst.cfg.pl nomodeset text systemd.unit=multi-user.target'"}
INST_SRC_OPTS=${INST_SRC_OPTS:-"--location=http://mirror.math.princeton.edu/pub/mageia/distrib/7.1/x86_64"}
#INST_SRC_OPTS=${INST_SRC_OPTS:-"--cdrom=/mnt/Data0/distros/fixed/mageia/Mageia-5-x86_64-DVD.iso"}

cp init/mageia/ext4-auto_inst.cfg.pl /tmp/auto_inst.cfg.pl
qemu-img create -f qcow2 /mnt/Data1/Virtual_Machs/vm_prac/${VM_NAME}.qcow2 30720M

virt-install --connect qemu:///system --virt-type kvm --machine q35 --video qxl --controller virtio-serial --console pty,target_type=serial --graphics vnc,port=-1 --memory 1536 --vcpus 2 --network network=default,model=virtio-net --boot menu=on,uefi,cdrom,hd,network --boot loader=/usr/share/OVMF/OVMF_CODE.fd --controller scsi,model=virtio-scsi --disk bus=scsi,path=/mnt/Data1/Virtual_Machs/vm_prac/${VM_NAME}.qcow2,cache=writeback,discard=unmap,format=qcow2 -n ${VM_NAME} --os-variant ${OS_VARIANT} ${INITRD_INJECT_OPTS} "${EXTRA_ARGS_OPTS}" ${INST_SRC_OPTS}
