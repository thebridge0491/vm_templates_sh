#!/bin/sh -x

## scripts/userifc.sh
set +e

export CHOICE_DESKTOP=${1:-xfce}

apt-get -y update ; apt-get -y dist-upgrade
. /root/init/pclinuxos/distro_pkgs.ini
case $CHOICE_DESKTOP in
	lxqt) pkgs_var="$pkgs_displaysvr_xorg $pkgs_deskenv_lxqt" ;;
	*) pkgs_var="$pkgs_displaysvr_xorg $pkgs_deskenv_xfce" ;;
esac
chkconfig --add dm ; chkconfig dm on

apt-get -y --option Retries=3 install drakconf acpi acpid $pkgs_var
# fix AND re-attempt install for infrequent errors
apt-get -y --fix-broken install
apt-get -y --option Retries=3 install drakconf acpi acpid $pkgs_var
sleep 3

XFdrake --auto
#drakx11 ; sleep 5 ; drakdm ; sleep 5 ; drakboot ; sleep 5
mv /etc/X11/xorg.conf /etc/X11/xorg.conf.bak || true

# update XDG user dir config
export LANG=en_US.UTF-8 ; export CHARSET=UTF-8
echo 'BIN=bin' >> /etc/xdg/user-dirs.defaults
xdg-user-dirs-update ; sleep 3

sed -i 's|nomodeset | |' /etc/default/grub
sed -i 's|text | |' /etc/default/grub
sed -i 's|noacpi | |' /etc/default/grub
sed -i 's|xdriver=vesa | |' /etc/default/grub
touch /etc/system-release
grub2-mkconfig -o /boot/grub2/grub.cfg
