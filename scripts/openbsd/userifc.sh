#!/bin/sh -eux

## scripts/userifc.sh
set +e

export CHOICE_DESKTOP=${1:-xfce}

# fetch missing distribution sets like: xbase59.tgz
#arch=$(arch -s) ; rel=$(sysctl -n kern.osrelease)
#ftp http://cdn.openbsd.org/pub/OpenBSD/${rel}/${arch}/xbase59.tgz
#tar -C / -xpzf xbase59.tgz ; sysmerge

arch=$(arch -s) ; rel=$(sysctl -n kern.osrelease)
setVer=$(echo ${rel} | tr '.' '\0')
cd /tmp
for setX in xbase xserv xfont xshare ; do
  ftp http://cdn.openbsd.org/pub/OpenBSD/${rel}/${arch}/${setX}${setVer}.tgz ;
  tar -C / -xpzf ${setX}${setVer}.tgz ;
done
sysmerge


pkg_add -u
. /root/init/openbsd/distro_pkgs.ini
case ${CHOICE_DESKTOP} in
	lxqt) pkgs_var="${pkgs_displaysvr_xorg} ${pkgs_deskenv_lxqt}" ;;
	*) pkgs_var="${pkgs_displaysvr_xorg} ${pkgs_deskenv_xfce}" ;;
esac

pkg_add -ziU -n ${pkgs_var}
for pkgX in ${pkgs_var} ; do
	pkg_add -ziU ${pkgX} ;
done
sleep 3

echo 'export XDG_CONFIG_HOME=/etc/xdg' >> /etc/rc.local
sleep 3

rcctl enable messagebus ; rcctl enable xenodm

# enable touchpad tapping
sed -i '/MatchIsTouchpad/a \ \ \ \ \ \ \ \ Option "Tapping" "on"' \
  /etc/X11/xorg.conf.d/10-evdev.conf
sed -i '/MatchIsTouchpad/a \ \ \ \ \ \ \ \ Option "Tapping" "on"' \
  /etc/X11/xorg.conf.d/40-libinput.conf

# update XDG user dir config
export LANG=en_US.UTF-8 ; export CHARSET=UTF-8
sh -c "echo 'BIN=bin' >> /etc/xdg/user-dirs.defaults"
xdg-user-dirs-update
