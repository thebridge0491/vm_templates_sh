OS_VARIANT=${OS_VARIANT:-generic} ; VM_NAME=${VM_NAME:-alpine-Stable-init}

INST_SRC_OPTS=${INST_SRC_OPTS:-"--cdrom=/mnt/Data0/distros/fixed/alpine/alpine-3.4.3-x86_64.iso"}

qemu-img create -f qcow2 /mnt/Data1/Virtual_Machs/vm_prac/${VM_NAME}.qcow2 30720M

virt-install --connect qemu:///system --virt-type kvm --machine q35 --video qxl --controller virtio-serial --console pty,target_type=serial --graphics vnc,port=-1 --memory 1536 --vcpus 2 --network network=default,model=virtio-net --boot menu=on,uefi,cdrom,hd,network --boot loader=/usr/share/OVMF/OVMF_CODE.fd --controller scsi,model=virtio-scsi --disk bus=scsi,path=/mnt/Data1/Virtual_Machs/vm_prac/${VM_NAME}.qcow2,cache=writeback,discard=unmap,format=qcow2 -n ${VM_NAME} --os-variant ${OS_VARIANT} ${INST_SRC_OPTS}

##!! login user/passwd: root/-


#ifconfig eth0 up ; udhcpc -i eth0

# nc -l [-p] {port} > file ## nc -w3 {host} {port} < file  # netcat xfr
# ssh user@ipaddr "su -c 'sh -xs - arg1 argN'" < script.sh
# ssh user@ipaddr "sudo sh -xs - arg1 argN" < script.sh  # w/ sudo

#sh /tmp/disk_setup.sh part_vmdisk sgdisk lvm vg0 pvol0
#sh /tmp/disk_setup.sh format_partitions lvm vg0 pvol0
#sh /tmp/disk_setup.sh mount_filesystems vg0

##NOTE, using transferred files: /tmp/answers, /tmp/post_autoinstall.sh

# passwd crypted hash: [md5|sha256|sha512] - [$1|$5|$6]$...
# python -c 'import crypt,getpass ; print(crypt.crypt(getpass.getpass(), "$6$16CHARACTERSSALT"))'
# perl -e 'print crypt("password", "\$6\$16CHARACTERSSALT") . "\n"'


#service sshd stop
#MIRROR='mirror.math.princeton.edu/pub/alpinelinux' ; APKREPOSOPTS=http://${MIRROR}/latest-stable/main BOOT_SIZE=200 BOOTLOADER=grub DISKLABEL=gpt setup-alpine -f /tmp/answers
#...
#...
#sh /tmp/post_autoinstall.sh $CRYPTED_PASSWD
