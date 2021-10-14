#!/bin/sh -eux

## scripts/userifc.sh
set +e

export CHOICE_DESKTOP=${1:-xfce}

if command -v aria2c > /dev/null ; then
	FETCH_CMD=${FETCH_CMD:-aria2c} ;
fi

pkg update ; pkg fetch -dy --available-updates ; pkg upgrade -y
. /root/init/freebsd/distro_pkgs.ini
case $CHOICE_DESKTOP in
	lxqt) pkgs_var="$pkgs_displaysvr_xorg $pkgs_deskenv_lxqt" ;;
	*) pkgs_var="$pkgs_displaysvr_xorg $pkgs_deskenv_xfce" ;;
esac

for pkgX in $pkgs_var ; do
	pkg fetch -Udy $pkgX ;
done
for pkgX in $pkgs_var ; do
	pkg install -Uy $pkgX ;
done
sleep 3

case $CHOICE_DESKTOP in
	lxqt) sysrc sddm_enable="YES" ;;
	*) #mv /usr/local/etc/lightdm /usr/local/etc/lightdm.old ;
	  sysrc lightdm_enable="YES" ;;
esac
sleep 3 ; chmod 1777 /tmp

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

# enable touchpad tapping
sed -i '' '/MatchIsTouchpad/a \ \ \ \ \ \ \ \ Option "Tapping" "on"' \
  /usr/local/share/X11/xorg.conf.d/10-evdev.conf
sed -i '' '/MatchIsTouchpad/a \ \ \ \ \ \ \ \ Option "Tapping" "on"' \
  /usr/local/share/X11/xorg.conf.d/40-libinput.conf

# update XDG user dir config
export LANG=en_US.UTF-8 ; export CHARSET=UTF-8
sh -c "echo 'BIN=bin' >> /usr/local/etc/xdg/user-dirs.defaults"
xdg-user-dirs-update
