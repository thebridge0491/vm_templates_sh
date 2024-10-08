#!/bin/sh -x

## scripts/userifc.sh
set +e

export CHOICE_DESKTOP=${1:-xfce}

apk fix ; apk update ; apk upgrade -U -a
. /root/init/alpine/distro_pkgs.ini
case ${CHOICE_DESKTOP} in
	*) pkgs_var="${pkgs_displaysvr_xorg} ${pkgs_deskenv_xfce}" ;;
esac

apk fetch ${pkgs_var}
setup-xorg-base
for pkgX in ${pkgs_var} ; do
	apk add ${pkgX} ;
done
sleep 3

rc-update add polkit default
case ${CHOICE_DESKTOP} in
	*) #mv /etc/lightdm /etc/lightdm.old ;
	  rc-update add lightdm default ;;
esac
chmod 1777 /tmp

# enable touchpad tapping
sed -i '/MatchIsTouchpad/a \ \ \ \ \ \ \ \ Option "Tapping" "on"' \
  /usr/share/X11/xorg.conf.d/10-evdev.conf
sed -i '/MatchIsTouchpad/a \ \ \ \ \ \ \ \ Option "Tapping" "on"' \
  /usr/share/X11/xorg.conf.d/40-libinput.conf
## ??? egrep -i 'synap|alps|etps|elan' /proc/bus/input/devices
#libinput list-devices ; xinput --list
#xinput list-props XX [; xinput disable YY] # by id, list-props or disable
#xinput set-prop <deviceid|devicename> <deviceproperty> <value>

## update XDG user dir config
#export LANG=en_US.UTF-8 ; export CHARSET=UTF-8
#echo 'BIN=bin' >> /etc/xdg/user-dirs.defaults
#xdg-user-dirs-update ; sleep 3

sed -i 's|nomodeset | |' /etc/default/grub
sed -i 's|text | |' /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg
