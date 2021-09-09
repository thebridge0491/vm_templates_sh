#!/bin/sh -x

## scripts/userifc.sh
set +e

export CHOICE_DESKTOP=${1:-xfce}

#urpmi.update -a ; urpmi --auto-update
dnf -y check-update ; dnf -y upgrade
. /root/init/mageia/distro_pkgs.ini
dnf --setopt=install_weak_deps=False config-manager --save
dnf config-manager --dump | grep -we install_weak_deps
case $CHOICE_DESKTOP in
	lxqt) pkgs_var="$pkgs_displaysvr_xorg $pkgs_deskenv_lxqt" ;;
	*) pkgs_var="$pkgs_displaysvr_xorg $pkgs_deskenv_xfce" ;;
esac

#urpmi --no-recommends --download-all $pkgs_var
dnf --setopt=install_weak_deps=False -y install --downloadonly $pkgs_var
for pkgX in $pkgs_var ; do
	#urpmi --no-recommends $pkgX ;
	#dnf --setopt=install_weak_deps=False -y install --cacheonly $pkgX ;
	dnf --setopt=install_weak_deps=False -y install $pkgX ;
done
sleep 3

systemctl enable display-manager
systemctl set-default graphical.target ; sleep 3

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
grub2-mkconfig -o /boot/grub2/grub.cfg
