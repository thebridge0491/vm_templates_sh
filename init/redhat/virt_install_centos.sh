OS_VARIANT=${OS_VARIANT:-centos7.0} ; VM_NAME=${VM_NAME:-centos-Release-init}

INITRD_INJECT_OPTS=${INITRD_INJECT_OPTS:-"--initrd-inject=/tmp/anaconda-ks.cfg"}
EXTRA_ARGS_OPTS=${EXTRA_ARGS_OPTS:-"--extra-args='inst.ks=file:///anaconda-ks.cfg ip=::::centos-boxv0000::dhcp hostname=centos-boxv0000 nomodeset video=1024x768 selinux=1 enforcing=0 text systemd.unit=multi-user.target inst.text'"}
INST_SRC_OPTS=${INST_SRC_OPTS:-"--location=http://mirror.math.princeton.edu/pub/centos/7/os/x86_64"}
#INST_SRC_OPTS=${INST_SRC_OPTS:-"--cdrom=/mnt/Data0/distros/fixed/centos/CentOS-7-x86_64-NetInstall-1511.iso"}

cp init/redhat/ext4-anaconda-ks.cfg /tmp/anaconda-ks.cfg
qemu-img create -f qcow2 /mnt/Data1/Virtual_Machs/vm_prac/${VM_NAME}.qcow2 30720M

virt-install --connect qemu:///system --virt-type kvm --machine q35 --video qxl --controller virtio-serial --console pty,target_type=serial --graphics vnc,port=-1 --memory 1536 --vcpus 2 --network network=default,model=virtio-net --boot menu=on,uefi,cdrom,hd,network --boot loader=/usr/share/OVMF/OVMF_CODE.fd --controller scsi,model=virtio-scsi --disk bus=scsi,path=/mnt/Data1/Virtual_Machs/vm_prac/${VM_NAME}.qcow2,cache=writeback,discard=unmap,format=qcow2 -n ${VM_NAME} --os-variant ${OS_VARIANT} ${INITRD_INJECT_OPTS} "${EXTRA_ARGS_OPTS}" ${INST_SRC_OPTS}

## NOTE, in kickstart failure to find ks.cfg:
##  Alt-Tab to cmdline
##  anaconda --kickstart <path>/anaconda-ks.cfg
