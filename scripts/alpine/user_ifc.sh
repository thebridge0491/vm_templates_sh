#!/bin/sh -x

set +e

CHOICE_DESKTOP=${CHOICE_DESKTOP:-xfce}

apk update ; apk upgrade -U -a
. /root/distro_pkgs.txt
case $CHOICE_DESKTOP in
	*) pkgs_var=$pkgs_deskenv_xfce ;;
esac

apk fetch $pkgs_var
setup-xorg-base
for pkgX in $pkgs_var ; do
	apk add $pkgX ;
done
sleep 3

case $CHOICE_DESKTOP in
	*) #mv /etc/lightdm /etc/lightdm.old ;
	  rc-update add lightdm default ;;
esac

## update XDG user dir config
#export LANG=en_US.UTF-8 ; export CHARSET=UTF-8
#echo 'BIN=bin' >> /etc/xdg/user-dirs.defaults
#xdg-user-dirs-update ; sleep 3

sed -i 's|nomodeset | |' /etc/default/grub
sed -i 's|text | |' /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg
