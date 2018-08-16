#!/bin/sh -x

set +e

CHOICE_DESKTOP=${CHOICE_DESKTOP:-lxde}

enable_svc() {
	svc=${1}
	. /etc/os-release
	case $ID in
		'devuan') update-rc.d $svc defaults ;;
		*) systemctl enable $svc ;;
	esac
}

apt-get update ; apt-get -y upgrade
. /root/distro_pkgs.txt
case $CHOICE_DESKTOP in
	lxqt) pkgs_var=$pkgs_deskenv_lxqt ;;
	*) pkgs_var=$pkgs_deskenv_lxde ;;
esac

apt-get -y --no-install-recommends install --download-only $pkgs_var
for pkgX in $pkgs_var ; do
	apt-get -y --no-install-recommends install $pkgX ;
done
sleep 3

case $CHOICE_DESKTOP in
	lxqt) enable_svc sddm ;;
	*) mv /etc/lightdm /etc/lightdm.old ;
	  enable_svc lightdm ;;
esac
#systemctl set-default graphical.target ; sleep 3

# update XDG user dir config
export LANG=en_US.UTF-8 ; export CHARSET=UTF-8
echo 'BIN=bin' >> /etc/xdg/user-dirs.defaults
xdg-user-dirs-update ; sleep 3
