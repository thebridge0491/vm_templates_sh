#!/bin/sh -eux

## scripts/userifc.sh
set +e

export CHOICE_DESKTOP=${1:-xfce}

# fetch missing distribution sets like: xbase.tar.xz
#arch=$(uname -m) ; rel=$(sysctl -n kern.osrelease)
#ftp http://cdn.netbsd.org/pub/NetBSD/NetBSD-${rel}/${arch}/binary/sets/xbase.tar.xz
#tar -C / -xpJf xbase.tar.xz

arch=$(uname -m) ; rel=$(sysctl -n kern.osrelease)
cd /tmp
for setX in xbase xserver xfont xetc ; do
  ftp http://cdn.netbsd.org/pub/NetBSD/NetBSD-${rel}/${arch}/binary/sets/${setX}.tar.xz ;
  tar -C / -xpJf ${setX}.tar.xz ;
done


pkgin update
. /root/init/netbsd/distro_pkgs.ini
case ${CHOICE_DESKTOP} in
	lxqt) pkgs_var="${pkgs_displaysvr_xorg} ${pkgs_deskenv_lxqt}" ;;
	*) pkgs_var="${pkgs_displaysvr_xorg} ${pkgs_deskenv_xfce}" ;;
esac

pkgin -yd install ${pkgs_var}
for pkgX in ${pkgs_var} ; do
	pkgin -y install ${pkgX} ;
done
sleep 3

groupadd -g 81 dbus ; mkdir -p /var/db/dbus /var/lib/xdm /usr/pkg/etc/xdm
useradd -c 'System message bus' -u 81 -g dbus -d '/' -s /usr/bin/false dbus

for svc in dbus xdm ; do
  cp /usr/pkg/share/examples/rc.d/${svc} /etc/rc.d/ ;
done
mkdir -p /var/run/dbus /var/run/xdm /var/lib/xdm

cp -R /usr/pkg/share/examples/xdm /usr/pkg/etc/

cat > /etc/X11/xorg.conf << EOF
Section "Device"
	Identifier "Card0"
	Driver "wsfb"
EndSection

EOF

cat >> /root/.xinitrc << EOF ;
export XDG_DATA_DIRS=/usr/pkg/share
export XDG_CONFIG_DIRS=/usr/pkg/etc/xdg

EOF

case ${CHOICE_DESKTOP} in
	lxqt) cat >> /root/.xinitrc << EOF ;
ck-launch-session dbus-launch --exit-with-session startlxqt

EOF
	  ;;
	xfce) cat >> /root/.xinitrc << EOF ;
ck-launch-session dbus-launch --exit-with-session startxfce4

EOF
	  ;;
esac
sleep 3

#echo 'dbus=YES' >> /etc/rc.conf
echo 'xdm=YES' >> /etc/rc.conf
echo 'wsmoused=YES' >> /etc/rc.conf

ln -s /root/.xinitrc /root/.xsession
cp /root/.xinitrc /home/packer/.xinitrc
chown packer:$(id -gn packer) /home/packer/.xinitrc
(cd /home/packer ; ln -s /home/packer/.xinitrc .xsession)

# set video resolution ? gop 6: 1024x768x32
sed -i 's|;boot|;gop 6;boot|g' /boot.cfg

# enable touchpad tapping
sed -i '/MatchIsTouchpad/a \ \ \ \ \ \ \ \ Option "Tapping" "on"' \
  /etc/X11/xorg.conf.d/10-evdev.conf
sed -i '/MatchIsTouchpad/a \ \ \ \ \ \ \ \ Option "Tapping" "on"' \
  /etc/X11/xorg.conf.d/40-libinput.conf

# update XDG user dir config
export LANG=en_US.UTF-8 ; export CHARSET=UTF-8
#sh -c "echo 'BIN=bin' >> /usr/pkg/etc/xdg/user-dirs.defaults"
sh -c "echo 'BIN=bin' >> /etc/xdg/user-dirs.defaults"
xdg-user-dirs-update
