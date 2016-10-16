OS_VARIANT=${OS_VARIANT:-debian8} ; VM_NAME=${VM_NAME:-debian-Stable-init}

INITRD_INJECT_OPTS=${INITRD_INJECT_OPTS:-"--initrd-inject=/tmp/preseed.cfg"}
EXTRA_ARGS_OPTS=${EXTRA_ARGS_OPTS:-"--extra-args='auto=true preseed/url=file:///preseed.cfg locale=en_US keymap=us console-setup/ask_detect=false hostname=debian-boxv0000 domain= mirror/http/hostname=ftp.us.debian.org mirror/http/directory=/debian'"}
INST_SRC_OPTS=${INST_SRC_OPTS:-"--location=http://mirror.math.princeton.edu/pub/debian/dists/stable/main/installer-amd64"}
#INST_SRC_OPTS=${INST_SRC_OPTS:-"--cdrom=/mnt/Data0/distros/fixed/debian/debian-8.6.0-amd64-netinst.iso"}

cp init/debian/ext4-preseed.cfg /tmp/preseed.cfg
qemu-img create -f qcow2 /mnt/Data1/Virtual_Machs/vm_prac/${VM_NAME}.qcow2 30720M

virt-install --connect qemu:///system --virt-type kvm --machine q35 --video qxl --controller virtio-serial --console pty,target_type=serial --graphics vnc,port=-1 --memory 1536 --vcpus 2 --network network=default,model=virtio-net --boot menu=on,uefi,cdrom,hd,network --boot loader=/usr/share/OVMF/OVMF_CODE.fd --controller scsi,model=virtio-scsi --disk bus=scsi,path=/mnt/Data1/Virtual_Machs/vm_prac/${VM_NAME}.qcow2,cache=writeback,discard=unmap,format=qcow2 -n ${VM_NAME} --os-variant ${OS_VARIANT} ${INITRD_INJECT_OPTS} "${EXTRA_ARGS_OPTS}" ${INST_SRC_OPTS}
