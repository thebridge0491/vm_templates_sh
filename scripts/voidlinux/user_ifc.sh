#!/bin/sh -x

set +e

CHOICE_DESKTOP=${CHOICE_DESKTOP:-lxde}

xbps-install -S ; xbps-install -y -u
. /root/distro_pkgs.txt
case $CHOICE_DESKTOP in
	lxqt) pkgs_var=$pkgs_deskenv_lxqt ;;
	*) pkgs_var=$pkgs_deskenv_lxde ;;
esac

xbps-install -y -D $pkgs_var
for pkgX in $pkgs_var ; do
	xbps-install -y $pkgX ;
done
sleep 3

case $CHOICE_DESKTOP in
	lxqt) ln -s /etc/sv/sdddm /etc/runit/runsvdir/default/sdddm ;;
	*) #mv /etc/lightdm /etc/lightdm.old ;
	  ln -s /etc/sv/lightdm /etc/runit/runsvdir/default/lightdm ;;
esac
ln -s /etc/sv/polkitd /etc/runit/runsvdir/default/polkitd

# update XDG user dir config
export LANG=en_US.UTF-8 ; export CHARSET=UTF-8
echo 'BIN=bin' >> /etc/xdg/user-dirs.defaults
xdg-user-dirs-update ; sleep 3

sed -i 's|nomodeset | |' /etc/default/grub
sed -i 's|text | |' /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

