#!/bin/sh -eux

set +e

CHOICE_DESKTOP=${CHOICE_DESKTOP:-xfce}

pkg_add -u
. /root/distro_pkgs.txt
case $CHOICE_DESKTOP in
	*) pkgs_var=$pkgs_deskenv_xfce ;;
esac

pkg_add -ziU -n $pkgs_var
for pkgX in $pkgs_var ; do
	pkg_add -ziU $pkgX ;
done
sleep 3

#rcctl enable xenodm
echo 'export XDG_CONFIG_HOME=/etc/xdg' >> /etc/rc.local
#case $CHOICE_DESKTOP in
#	*) echo '/etc/rc.d/slim start' >> /etc/rc.local ;
#	  rcctl enable slim ;;
#esac
sleep 3

rcctl enable messagebus

# update XDG user dir config
export LANG=en_US.UTF-8 ; export CHARSET=UTF-8
sh -c "echo 'BIN=bin' >> /etc/xdg/user-dirs.defaults"
xdg-user-dirs-update
