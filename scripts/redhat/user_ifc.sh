#!/bin/sh -x

set +e

CHOICE_DESKTOP=${CHOICE_DESKTOP:-xfce}

yum -y check-update ; yum -y upgrade
. /root/distro_pkgs.txt
case $CHOICE_DESKTOP in
	lxqt) pkgs_var=$pkgs_deskenv_lxqt ;;
	*) pkgs_var=$pkgs_deskenv_xfce ;;
esac

yum -y --setopt=requires_policy=strong --setopt=group_package_type=mandatory install --downloadonly $pkgs_var
for pkgX in $pkgs_var ; do
	yum -y --setopt=requires_policy=strong --setopt=group_package_type=mandatory install --cacheonly $pkgX ;
done
sleep 3

case $CHOICE_DESKTOP in
	lxqt) systemctl enable sddm ;;
	*) mv /etc/lightdm /etc/lightdm.old ;
	  systemctl enable lightdm ;;
esac
systemctl set-default graphical.target ; sleep 3

# update XDG user dir config
export LANG=en_US.UTF-8 ; export CHARSET=UTF-8
echo 'BIN=bin' >> /etc/xdg/user-dirs.defaults
xdg-user-dirs-update ; sleep 3
