#!/bin/sh -x

## scripts/userifc.sh
set +e

export CHOICE_DESKTOP=${1:-xfce}

zypper --non-interactive refresh ; zypper --non-interactive update
. /root/init/suse/distro_pkgs.ini
sed -i 's|.*solver.onlyRequires.*=.*|solver.onlyRequires = true|' \
  /etc/zypp/zypp.conf
sed -i 's|.*installRecommends.*=.*|installRecommends = no|' \
  /etc/zypp/zypper.conf
case $CHOICE_DESKTOP in
	lxqt) pkgs_var="$pkgs_displaysvr_xorg $pkgs_deskenv_lxqt" ;;
	*) pkgs_var="$pkgs_displaysvr_xorg $pkgs_deskenv_xfce" ;;
esac

zypper --non-interactive install --download-only --no-recommends $pkgs_var
for pkgX in $pkgs_var ; do
	zypper --non-interactive install --no-recommends $pkgX ;
done
sleep 3

systemctl enable display-manager
systemctl set-default graphical.target ; sleep 3
chmod 1777 /tmp

# enable touchpad tapping
sed -i '/MatchIsTouchpad/a \ \ \ \ \ \ \ \ Option "Tapping" "on"' \
  /etc/X11/xorg.conf.d/10-evdev.conf
sed -i '/MatchIsTouchpad/a \ \ \ \ \ \ \ \ Option "Tapping" "on"' \
  /etc/X11/xorg.conf.d/40-libinput.conf

# update XDG user dir config
export LANG=en_US.UTF-8 ; export CHARSET=UTF-8
echo 'BIN=bin' >> /etc/xdg/user-dirs.defaults
xdg-user-dirs-update ; sleep 3

sed -i 's|nomodeset | |' /etc/default/grub
sed -i 's|text | |' /etc/default/grub
grub2-mkconfig -o /boot/grub2/grub.cfg
