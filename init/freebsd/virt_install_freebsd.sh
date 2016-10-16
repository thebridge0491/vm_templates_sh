OS_VARIANT=${OS_VARIANT:-generic} ; VM_NAME=${VM_NAME:-freebsd-Release-init}

INST_SRC_OPTS=${INST_SRC_OPTS:-"--cdrom=/mnt/Data0/distros/fixed/freebsd/FreeBSD-11.0-RELEASE-amd64-disc1.iso"}

qemu-img create -f qcow2 /mnt/Data1/Virtual_Machs/vm_prac/${VM_NAME}.qcow2 30720M

virt-install --connect qemu:///system --virt-type kvm --machine q35 --video qxl --controller virtio-serial --console pty,target_type=serial --graphics vnc,port=-1 --memory 1536 --vcpus 2 --network network=default,model=virtio-net --boot menu=on,uefi,cdrom,hd,network --boot loader=/usr/share/OVMF/OVMF_CODE.fd --controller scsi,model=virtio-scsi --disk bus=scsi,path=/mnt/Data1/Virtual_Machs/vm_prac/${VM_NAME}.qcow2,cache=writeback,discard=unmap,format=qcow2 -n ${VM_NAME} --os-variant ${OS_VARIANT} ${INST_SRC_OPTS}

##NOTE, navigate to single user: 2


#mdmfs -s 100m md1 /tmp ; dhclient -l /tmp/dhclient.leases -p /tmp/dhclient.pid em0 ; dhclient -l /tmp/dhclient.leases -p /tmp/dhclient.lease.vtnet0 vtnet0 ; cd /tmp

# nc -l [-p] {port} > file ## nc -w3 {host} {port} < file  # netcat xfr
# ssh user@ipaddr "sudo sh -xs - arg1 argN" < script.sh  # w/ sudo
# ssh user@ipaddr "su -m root -c 'sh -xs - arg1 argN'" < script.sh

##NOTE, using transferred files: /tmp/installerconfig

#sh /tmp/disk_setup.sh gpart_vmdisk zfs
#sh /tmp/disk_setup.sh format_partitions zfs
#sh /tmp/disk_setup.sh mount_filesystems

# passwd crypted hash: [md5|sha256|sha512] - [$1|$5|$6]$...
# python -c 'import crypt,getpass ; print(crypt.crypt(getpass.getpass(), "$6$16CHARACTERSSALT"))'
# perl -e 'print crypt("password", "\$6\$16CHARACTERSSALT") . "\n"'

#CRYPTED_PASSWD=$CRYPTED_PASSWD INIT_HOSTNAME=$INIT_HOSTNAME DEVX=da0 bsdinstall script /tmp/installerconfig
