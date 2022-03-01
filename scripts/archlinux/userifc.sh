#!/bin/sh -x

## scripts/userifc.sh
set +e

export CHOICE_DESKTOP=${1:-xfce}

svc_enable() {
  svc=${1}
  if command -v systemctl > /dev/null ; then
    systemctl enable $svc ;
  elif command -v s6-rc > /dev/null ; then
    s6-rc-bundle-update add default $svc ;
  elif command -v sv > /dev/null ; then
    ln -s /etc/runit/sv/$svc /run/runit/service/ ;
  elif command -v rc-update > /dev/null ; then
  	rc-update add $svc default ;
  fi
}

if command -v systemctl > /dev/null ; then
  systemctl stop pamac.service ;
elif command -v s6-rc > /dev/null ; then
  s6-rc -d change pamac ;
elif command -v sv > /dev/null ; then
  sv down pamac ;
elif command -v rc-update > /dev/null ; then
  rc-service pamac stop ;
fi
rm /var/lib/pacman/db.lck

pacman --noconfirm -Syy ; pacman --noconfirm -Syu
. /root/init/archlinux/distro_pkgs.ini
case $CHOICE_DESKTOP in
	lxqt) pkgs_var="$pkgs_displaysvr_xorg $pkgs_deskenv_lxqt" ;;
	*) pkgs_var="$pkgs_displaysvr_xorg $pkgs_deskenv_xfce" ;;
esac

for pkgX in $pkgs_var ; do
	pacman --noconfirm --needed -Sw $pkgX ;
done
for pkgX in $pkgs_var ; do
	pacman --noconfirm --needed -S $pkgX ;
done

if [ -f /etc/os-release ] ; then
  . /etc/os-release ;
elif [ -f /usr/lib/os-release ] ; then
  . /usr/lib/os-release ;
fi
if command -v s6-rc > /dev/null ; then
  service_mgr=s6 ;
elif command -v sv > /dev/null ; then
  service_mgr=runit ;
elif command -v rc-update > /dev/null ; then
  service_mgr=openrc ;
fi

if [ "artix" = "${ID}" ] ; then
  pacman --noconfirm --needed -S displaymanager-${service_mgr} ;
fi
sleep 3

svc_enable display-manager
if command -v systemctl > /dev/null ; then
  systemctl set-default graphical.target ; sleep 3 ;
elif command -v s6-rc > /dev/null ; then
  svc_enable xdm ;
  sed -i "s|DISPLAYMANAGER=.*|DISPLAYMANAGER='$CHOICE_DESKTOP'|" etc/conf.d/xdm ;
elif command -v sv > /dev/null ; then
  svc_enable xdm ;
  sed -i "s|DISPLAYMANAGER=.*|DISPLAYMANAGER='$CHOICE_DESKTOP'|" etc/conf.d/xdm ;
elif command -v rc-update > /dev/null ; then
  svc_enable xdm ;
  sed -i "s|DISPLAYMANAGER=.*|DISPLAYMANAGER='$CHOICE_DESKTOP'|" etc/conf.d/xdm ;
fi
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
