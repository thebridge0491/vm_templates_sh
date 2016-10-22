#!/bin/sh -x

set +e

## freebsd/vm_tools.sh
if command -v aria2c > /dev/null 2>&1 ; then
	FETCH_CMD=${FETCH_CMD:-aria2c} ;
fi
PACKER_BUILDER_TYPE=${PACKER_BUILDER_TYPE:-qemu}
WITH_X11=${WITH_X11:-x11}

pkg -o OSVERSION=9999999 update -f ; pkg upgrade -y

if [ "nox11" = "$WITH_X11" ] ; then
	case "$PACKER_BUILDER_TYPE" in
	  qemu) echo '' ;;
	  virtualbox-iso|virtualbox-ovf)
		pkg fetch -dy virtualbox-ose-additions-nox11 ;
		pkg install -y virtualbox-ose-additions-nox11 ;
		
		sysrc -f /boot/loader.conf vboxdrv_load="YES" ;
		#sysrc -f /boot/loader.conf virtio_load="YES" ;
		#sysrc -f /boot/loader.conf virtio_pci_load="YES" ;
		#sysrc -f /boot/loader.conf virtio_blk_load="YES" ;
		
		if [ "$freebsd_major" -gt 9 ] ; then
		  # Appeared in FreeBSD 10
		  #sysrc -f /boot/loader.conf virtio_scsi_load="YES" ;
		fi ;
		#sysrc -f /boot/loader.conf virtio_balloon_load="YES" ;
		#sysrc -f /boot/loader.conf if_vtnet_load="YES" ;
		
		sysrc vboxguest_enable="YES" ;
		sysrc vboxservice_enable="YES" ;
		sysrc vboxnet_enable="YES" ;
		
		pw groupadd vboxusers ;
		pw groupmod vboxusers -m packer ; pw groupmod vboxusers -m vagrant ;
		;;
	  *)
		echo "Unknown Packer Builder Type: $PACKER_BUILDER_TYPE." ;
		echo "Known are qemu|virtualbox-[iso|ovf]." ;
		;;
	esac ;
else
	freebsd_major="$(uname -r | awk -F. '{print $1}')" ;

	# set a default HOME_DIR environment variable if not set
	HOME_DIR="${HOME_DIR:-/home/packer}" ;

	case "$PACKER_BUILDER_TYPE" in
	  qemu) echo '' ;;
	  virtualbox-iso|virtualbox-ovf)
		# Disable X11 because vagrants are (usually) headless
		echo '#WITHOUT_X11="YES"' >> /etc/make.conf ;
		
		pkg delete -y virtualbox-ose-additions-nox11 ;
		pkg fetch -dy virtualbox-ose-additions ;
		pkg install -y virtualbox-ose-additions ;
		
		sysrc -f /boot/loader.conf vboxdrv_load="YES" ;
		#sysrc -f /boot/loader.conf virtio_load="YES" ;
		#sysrc -f /boot/loader.conf virtio_pci_load="YES" ;
		#sysrc -f /boot/loader.conf virtio_blk_load="YES" ;
		
		if [ "$freebsd_major" -gt 9 ] ; then
		  # Appeared in FreeBSD 10
		  #sysrc -f /boot/loader.conf virtio_scsi_load="YES" ;
		fi ;
		#sysrc -f /boot/loader.conf virtio_balloon_load="YES" ;
		#sysrc -f /boot/loader.conf if_vtnet_load="YES" ;
		## Don't waste 10 seconds waiting for boot
		#sysrc -f /boot/loader.conf autoboot_delay="-1" ;
		
		sysrc vboxguest_enable="YES" ;
		sysrc vboxservice_enable="YES" ;
		sysrc vboxnet_enable="YES" ;
		#sysrc ifconfig_vtnet0_name="em0" ;
		
		pw groupadd vboxusers ;
		pw groupmod vboxusers -m packer ; pw groupmod vboxusers -m vagrant ;
		;;
	  *)
		echo "Unknown Packer Builder Type: $PACKER_BUILDER_TYPE." ;
		echo "Known are qemu|virtualbox-[iso|ovf]." ;
		;;
	esac ;
fi
