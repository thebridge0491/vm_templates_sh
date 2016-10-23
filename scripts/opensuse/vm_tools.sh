#!/bin/sh -eux

set +e

## opensuse/vm_tools.sh
PACKER_BUILDER_TYPE=${PACKER_BUILDER_TYPE:-qemu}
WITH_X11=${WITH_X11:-x11}

zypper --non-interactive refresh ; zypper --non-interactive update

if [ "nox11" = "$WITH_X11" ] ; then
	case "$PACKER_BUILDER_TYPE" in
	  qemu) echo '' ;;
	  virtualbox-iso|virtualbox-ovf)
		zypper --non-interactive install virtualbox-guest-tools ;
		systemctl enable vboxadd-service
		groupadd --system vboxsf ;
		usermod -aG vboxsf packer ; usermod -aG vboxsf vagrant ;#vbox[sf|guest]

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
		zypper --non-interactive install kernel-devel ; # kernel-[devel|source]
		#VER="$(cat $HOME_DIR/.vbox_version)" ;
		#echo "Virtualbox Tools Version: $VER" ;
		#mkdir -p /tmp/vbox ;
		#mount -o loop $HOME_DIR/VBoxGuestAdditions_${VER}.iso /tmp/vbox ;
		#sh /tmp/vbox/VBoxLinuxAdditions.run \
		#    || echo "VBoxLinuxAdditions.run exited $? and is " \
		#    "suppressed. For more read " \
		#    "https://www.virtualbox.org/ticket/12479" ;
		#umount /tmp/vbox ; rm -rf /tmp/vbox ;
		zypper --non-interactive rl virtualbox-guest-kmp-default ;
		zypper --non-interactive rl virtualbox-guest-x11 ;
		zypper --non-interactive install virtualbox-guest-tools virtualbox-guest-x11 ;
		rm -f $HOME_DIR/*.iso ;
		usermod -aG vboxsf packer ; usermod -aG vboxsf vagrant ;#vbox[sf|guest]
		;;
	  *)
		echo "Unknown Packer Builder Type: $PACKER_BUILDER_TYPE." ;
		echo "Known are qemu|virtualbox-[iso|ovf]." ;
		;;
	esac ;
fi

# Remove development and kernel source packages
# These were only needed for building VMware/Virtualbox extensions:
#zypper -n rm -u binutils gcc make perl ruby kernel-default-devel kernel-devel
