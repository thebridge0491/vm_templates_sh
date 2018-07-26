OS_VARIANT=${OS_VARIANT:-generic} ; VM_NAME=${VM_NAME:-netbsd-Release-init}

INST_SRC_OPTS=${INST_SRC_OPTS:-"--cdrom=/mnt/Data0/distros/fixed/netbsd/NetBSD-7.0.1-amd64.iso"}

qemu-img create -f qcow2 /mnt/Data1/Virtual_Machs/vm_prac/${VM_NAME}.qcow2 30720M

virt-install --connect qemu:///system --virt-type kvm --machine pc --video cirrus --controller virtio-serial --console pty,target_type=serial --graphics vnc,port=-1 --memory 1536 --vcpus 2 --network network=default,model=virtio-net --boot menu=on,cdrom,hd,network --controller scsi,model=virtio-scsi --disk bus=scsi,path=/mnt/Data1/Virtual_Machs/vm_prac/${VM_NAME}.qcow2,cache=writeback,discard=unmap,format=qcow2 -n ${VM_NAME} --os-variant ${OS_VARIANT} ${INST_SRC_OPTS}

##NOTE, navigate thru installer to shell: 1 ; a ; a ; e ; a


#ksh ; mount_mfs -s 100m md1 /tmp ; mount_mfs -s 100m md2 /mnt ; dhcpcd wm0 ; dhcpcd vioif0 ; cd /tmp

# nc -l [-p] {port} > file ## nc -w3 {host} {port} < file  # netcat xfr
# ssh user@ipaddr "sudo sh -xs - arg1 argN" < script.sh  # w/ sudo
# ssh user@ipaddr "su -m root -c 'sh -xs - arg1 argN'" < script.sh

##NOTE, using transferred files: /tmp/disk_setup.sh, /tmp/install.sh

#sh /tmp/disk_setup.sh gpt_vmdisk ffs
#sh /tmp/disk_setup.sh format_partitions ffs
#sh /tmp/disk_setup.sh mount_filesystems

# passwd crypted hash: [md5|sha256|sha512] - [$1|$5|$6]$...
# python -c 'import crypt,getpass ; print(crypt.crypt(getpass.getpass(), "$6$16CHARACTERSSALT"))'
# perl -e 'print crypt("password", "\$6\$16CHARACTERSSALT") . "\n"'

#sh /tmp/install.sh $PLAIN_PASSWD $INIT_HOSTNAME
