#!/bin/sh -x

set +e

CHOICE_DESKTOP=${CHOICE_DESKTOP:-lxde}

apt-get update ; apt-get -y dist-upgrade
. /root/distro_pkgs.txt
case $CHOICE_DESKTOP in
	lxqt) pkgs_var=$pkgs_deskenv_lxqt ; chkconfig --add lightdm ;;
	*) pkgs_var=$pkgs_deskenv_lxde ; chkconfig --add slim ;;
esac

apt-get -y --option Retries=3 install drakconf acpi acpid $pkgs_var
# fix AND re-attempt install for infrequent errors
apt-get -y --fix-broken install
apt-get -y --option Retries=3 install drakconf acpi acpid $pkgs_var
sleep 3

#XFdrake --auto
drakx11 ; sleep 5 ; drakdm ; sleep 5 ; drakboot ; sleep 500
mv /etc/X11/xorg.conf /etc/X11/xorg.conf.bak

# update XDG user dir config
export LANG=en_US.UTF-8 ; export CHARSET=UTF-8
echo 'BIN=bin' >> /etc/xdg/user-dirs.defaults
xdg-user-dirs-update ; sleep 3
