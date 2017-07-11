#!/bin/bash

CHOICE_DESKTOP=${CHOICE_DESKTOP:-}
PACKER_CMD=${PACKER_CMD:-$HOME/bin/packer}

# example usage:
#   (ssh host): sh provision_vm.sh 192.168.0.2 abcd0123 update-vm freebsd
#   (ovf path): sh provision_vm.sh freebsd-Release abcd0123 update-ovf freebsd

VM_SPEC=${1:-192.168.0.2} ; PLAIN_PASSWD=${2:-abcd0123}
BUILD_NAME=${3:-update-vm} ; DISTRO_NAME=${4:-freebsd}

if [ ! -d "scripts/$DISTRO_NAME" ] ; then
	echo "Unknown selection ($DISTRO_NAME) ... exiting" ; exit 0 ;
fi

if [ -e output-vms/${VM_SPEC} ] ; then
	mkdir -p input-vms/${VM_SPEC} ;
	mv -vi output-vms/${VM_SPEC}/* input-vms/${VM_SPEC}/ ;
fi

case $DISTRO_NAME in
	'freebsd'|'openbsd'|'netbsd')
		$PACKER_CMD build -only=$BUILD_NAME -var distro_name=$DISTRO_NAME \
			-var vm_spec=$VM_SPEC -var desktop=$CHOICE_DESKTOP \
			-var plain_passwd=$PLAIN_PASSWD -force provision-bsd.json ;;
	'redhat'|'centos')
		$PACKER_CMD build -only=$BUILD_NAME -var distro_name=redhat \
			-var vm_spec=$VM_SPEC -var desktop=$CHOICE_DESKTOP \
			-var plain_passwd=$PLAIN_PASSWD -force provision-linux.json ;;
	*)
		$PACKER_CMD build -only=$BUILD_NAME -var distro_name=$DISTRO_NAME \
			-var vm_spec=$VM_SPEC -var desktop=$CHOICE_DESKTOP \
			-var plain_passwd=$PLAIN_PASSWD -force provision-linux.json ;;
esac

#----------------------------------------
#$@
