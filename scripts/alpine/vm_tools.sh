#!/bin/sh -x

set +e

## alpine/vm_tools.sh
PACKER_BUILDER_TYPE=${PACKER_BUILDER_TYPE:-qemu}
WITH_X11=${WITH_X11:-x11}

apk update ; apk upgrade -U -a

if [ "nox11" = "$WITH_X11" ] ; then
	case "$PACKER_BUILDER_TYPE" in
	  qemu) echo '' ;;
	  virtualbox-iso|virtualbox-ovf)
		apk add virtualbox-guest-additions virtualbox-guest-modules-hardened ;
		rc-update add virtualbox-guest-additions ;
		echo vboxsf >> /etc/modules ;
		usermod -aG vboxsf packer ; usermod -aG vboxsf vagrant ;

#	sh -c 'cat >> /etc/fstab' << EOF ;
#Data0      /media/sf_Data0    vboxsf      noauto,rw,dmask=0002,fmask=0113,gid=vboxsf  0   0
#
#EOF
#	mkdir -p /media/sf_Data0 ;
#	chown root:vboxsf /media/sf_Data0 ;
		;;
	  *)
		echo "Unknown Packer Builder Type: $PACKER_BUILDER_TYPE." ;
		echo "Known are qemu|virtualbox-[iso|ovf]." ;
		;;
	esac ;
else
	# set a default HOME_DIR environment variable if not set
	HOME_DIR="${HOME_DIR:-/home/packer}" ;

	case "$PACKER_BUILDER_TYPE" in
	  qemu) echo '' ;;
	  virtualbox-iso|virtualbox-ovf)
		#apk add linux-lts-headers ;
		#VER="$(cat $HOME_DIR/.vbox_version)" ;
		#echo "Virtualbox Tools Version: $VER" ;
		#mkdir -p /tmp/vbox ;
		#mount -o loop $HOME_DIR/VBoxGuestAdditions_${VER}.iso /tmp/vbox ;
		#sh /tmp/vbox/VBoxLinuxAdditions.run \
		#    || echo "VBoxLinuxAdditions.run exited $? and is " \
		#    "suppressed. For more read " \
		#    "https://www.virtualbox.org/ticket/12479" ;
		#umount /tmp/vbox ; rm -rf /tmp/vbox ;
		apk add virtualbox-guest-additions-x11 ;
		rc-update add virtualbox-guest-additions ;
		rm -f $HOME_DIR/*.iso ;
		usermod -aG vboxsf packer ; usermod -aG vboxsf vagrant ;
		;;
	  *)
		echo "Unknown Packer Builder Type: $PACKER_BUILDER_TYPE." ;
		echo "Known are qemu|virtualbox-[iso|ovf]." ;
		;;
	esac ;
fi
