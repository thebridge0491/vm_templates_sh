#!/bin/sh -x

set +e

## redhat/vm_tools.sh
PACKER_BUILDER_TYPE=${PACKER_BUILDER_TYPE:-qemu}
WITH_X11=${WITH_X11:-x11}

yum -y check-update ; yum -y upgrade

if [ "nox11" = "$WITH_X11" ] ; then
	case "$PACKER_BUILDER_TYPE" in
	  qemu) echo '' ;;
	  virtualbox-iso|virtualbox-ovf)
		#systemctl enable vboxservice
		groupadd --system vboxsf ;
		usermod -aG vboxsf packer ; usermod -aG vboxsf vagrant ;

#	sh -c 'cat >> /etc/fstab' << EOF ;
#Data0      /media/sf_Data0    vboxsf      noauto,rw,dmask=0002,fmask=0113,gid=vboxsf  0   0
#
#EOF
#	chmod 0755 /media ; mkdir -p /media/sf_Data0 ;
#	chown root:vboxsf /media/sf_Data0 ;
		;;
	  *)
		echo "Unknown Packer Builder Type: $PACKER_BUILDER_TYPE." ;
		echo "Known are qemu|virtualbox-[iso|ovf]." ;
		;;
	esac ;
else
	# set a default HOME_DIR environment variable if not set
	HOME_DIR="${HOME_DIR:-/home/packer}"

	case "$PACKER_BUILDER_TYPE" in
	  qemu) echo '' ;;
	  virtualbox-iso|virtualbox-ovf)
		yum -y install kernel-devel	; # kernel-[devel|headers]
		VER="$(cat $HOME_DIR/.vbox_version)" ;
		echo "Virtualbox Tools Version: $VER" ;
		mkdir -p /tmp/vbox ;
		mount -o loop $HOME_DIR/VBoxGuestAdditions_${VER}.iso /tmp/vbox ;
		sh /tmp/vbox/VBoxLinuxAdditions.run \
			|| echo "VBoxLinuxAdditions.run exited $? and is " \
			"suppressed. For more read " \
			"https://www.virtualbox.org/ticket/12479" ;
		umount /tmp/vbox ; rm -rf /tmp/vbox ;
		#yum -y install VirtualBox-guest ;
		rm -f $HOME_DIR/*.iso ;
		groupadd --system vboxsf ;
		usermod -aG vboxsf packer ; usermod -aG vboxsf vagrant ;
		;;
	  *)
		echo "Unknown Packer Builder Type: $PACKER_BUILDER_TYPE." ;
		echo "Known are qemu|virtualbox-[iso|ovf]." ;
		;;
	esac ;
fi
