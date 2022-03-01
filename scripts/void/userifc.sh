#!/bin/sh -x

## scripts/userifc.sh
set +e

export CHOICE_DESKTOP=${1:-xfce}

xbps-install -S ; xbps-install -y -u
. /root/init/void/distro_pkgs.ini
case $CHOICE_DESKTOP in
	lxqt) pkgs_var="$pkgs_displaysvr_xorg $pkgs_deskenv_lxqt" ;;
	*) pkgs_var="$pkgs_displaysvr_xorg $pkgs_deskenv_xfce" ;;
esac

for pkgX in $pkgs_var ; do
	xbps-install -y -D $pkgX ;
done
for pkgX in $pkgs_var ; do
	xbps-install -y $pkgX ;
done
sleep 3

case $CHOICE_DESKTOP in
	lxqt) ln -s /etc/sv/sddm /etc/runit/runsvdir/default/ ;;
	*) #mv /etc/lightdm /etc/lightdm.old ;
	  ln -s /etc/sv/lightdm /etc/runit/runsvdir/default/ ;;
esac
ln -s /etc/sv/dbus /etc/runit/runsvdir/default/
ln -s /etc/sv/polkitd /etc/runit/runsvdir/default/
chmod 1777 /tmp

# enable touchpad tapping
sed -i '/MatchIsTouchpad/a \ \ \ \ \ \ \ \ Option "Tapping" "on"' \
  /usr/share/X11/xorg.conf.d/10-evdev.conf
sed -i '/MatchIsTouchpad/a \ \ \ \ \ \ \ \ Option "Tapping" "on"' \
  /usr/share/X11/xorg.conf.d/40-libinput.conf

# update XDG user dir config
export LANG=en_US.UTF-8 ; export CHARSET=UTF-8
echo 'BIN=bin' >> /etc/xdg/user-dirs.defaults
xdg-user-dirs-update ; sleep 3

sed -i 's|nomodeset | |' /etc/default/grub
sed -i 's|text | |' /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

