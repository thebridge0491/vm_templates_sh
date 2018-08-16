#!/bin/sh -eux

set +e

CHOICE_DESKTOP=${CHOICE_DESKTOP:-lxde}

pkgin update
. /root/distro_pkgs.txt
case $CHOICE_DESKTOP in
	*) pkgs_var=$pkgs_deskenv_lxde ;;
esac

pkgin -yd install $pkgs_var
for pkgX in $pkgs_var ; do
	pkgin -y install $pkgX ;
done
sleep 3

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

case $CHOICE_DESKTOP in
	*) cat >> /root/.xinitrc << EOF ;
ck-launch-session dbus-launch --exit-with-session startlxde

EOF
	  echo '#xdm=YES' >> /etc/rc.conf ;;
esac
sleep 3

echo 'hal=YES' >> /etc/rc.conf
#echo 'dbus=YES' >> /etc/rc.conf

ln -s /root/.xinitrc /root/.xsession
cp /root/.xinitrc /home/packer/.xinitrc
chown packer:$(id -gn packer) /home/packer/.xinitrc
(cd /home/packer ; ln -s /home/packer/.xinitrc .xsession)

# set video resolution ? gop 6: 1024x768x32
sed -i 's|;boot|;gop 6;boot|g' /boot.cfg

# update XDG user dir config
export LANG=en_US.UTF-8 ; export CHARSET=UTF-8
sh -c "echo 'BIN=bin' >> /usr/pkg/etc/xdg/user-dirs.defaults"
xdg-user-dirs-update
