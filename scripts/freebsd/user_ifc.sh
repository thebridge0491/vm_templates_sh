#!/bin/sh -eux

set +e

if command -v aria2c > /dev/null 2>&1 ; then
	FETCH_CMD=${FETCH_CMD:-aria2c} ;
fi
CHOICE_DESKTOP=${CHOICE_DESKTOP:-lxde}

pkg update ; pkg fetch -dy --available-updates ; pkg upgrade -y
. /root/distro_pkgs.txt
case $CHOICE_DESKTOP in
	lxqt) pkgs_var=$pkgs_deskenv_lxqt ;;
	*) pkgs_var=$pkgs_deskenv_lxde ;;
esac

pkg fetch -dy $pkgs_var
for pkgX in $pkgs_var ; do
	pkg install -y $pkgX ;
done
sleep 3

case $CHOICE_DESKTOP in
	lxqt) sysrc sddm_enable="YES" ;;
	*) mv /usr/local/etc/lightdm /usr/local/etc/lightdm.old ;
	  sysrc lightdm_enable="YES" ;;
esac
sleep 3

# config xorg
sh -c 'cat >> /boot/loader.conf' << EOF
kern.vty=vt
hw.psm.synaptics_support="1"

EOF
sh -c 'cat >> /etc/profile.conf' << EOF
LANG=en_US.UTF-8 ; export LANG
CHARSET=UTF-8 ; export CHARSET

EOF
sysrc dbus_enable="YES"
sysrc hald_enable="YES"
#sysrc mixer_enable="YES"
sysrc moused_enable="YES"    

# update XDG user dir config
export LANG=en_US.UTF-8 ; export CHARSET=UTF-8
sh -c "echo 'BIN=bin' >> /usr/local/etc/xdg/user-dirs.defaults"
xdg-user-dirs-update
