#!/bin/sh -x

set +e

CHOICE_DESKTOP=${CHOICE_DESKTOP:-lxde}

systemctl stop pamac.service
rm /var/lib/pacman/db.lck

pacman --noconfirm -Syy ; pacman --noconfirm -Syu
. /root/distro_pkgs.txt
case $CHOICE_DESKTOP in
	*) pkgs_var=$pkgs_deskenv_lxde ;;
esac

pacman --noconfirm --needed -Sw $pkgs_var
for pkgX in $pkgs_var ; do
	pacman --noconfirm --needed -S $pkgX ;
done
sleep 3

case $CHOICE_DESKTOP in
	*) mv /etc/lightdm /etc/lightdm.old ;
	  systemctl enable lightdm ;;
esac
systemctl set-default graphical.target ; sleep 3

# update XDG user dir config
export LANG=en_US.UTF-8 ; export CHARSET=UTF-8
echo 'BIN=bin' >> /etc/xdg/user-dirs.defaults
xdg-user-dirs-update ; sleep 3
