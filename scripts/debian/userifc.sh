#!/bin/sh -x

## scripts/userifc.sh
set +e

export CHOICE_DESKTOP=${1:-xfce}

svc_enable() {
  svc=${1}
  if command -v systemctl > /dev/null ; then
    systemctl enable ${svc} ;
  elif command -v sv > /dev/null ; then
    ln -s /etc/sv/${svc} /var/service ;
  elif command -v rc-update > /dev/null ; then
    rc-update add ${svc} default ;
  elif command -v update-rc.d > /dev/null ; then
  	update-rc.d ${svc} defaults ;
  fi
}

apt-get -y update --allow-releaseinfo-change ; apt-get -y upgrade
. /root/init/debian/distro_pkgs.ini
apt-config dump | grep -we Recommends -e Suggests | sed 's|1|0|' | \
  tee /etc/apt/apt.conf.d/999norecommends
case ${CHOICE_DESKTOP} in
	lxqt) pkgs_var="${pkgs_displaysvr_xorg} ${pkgs_deskenv_lxqt}" ;;
	*) pkgs_var="${pkgs_displaysvr_xorg} ${pkgs_deskenv_xfce}" ;;
esac

for pkgX in ${pkgs_var} ; do
	apt-get -y --no-install-recommends install --download-only ${pkgX} ;
done
for pkgX in ${pkgs_var} ; do
	apt-get -y --no-install-recommends install ${pkgX} ;
done
sleep 3

case ${CHOICE_DESKTOP} in
	lxqt) svc_enable sddm ;;
	*) #mv /etc/lightdm /etc/lightdm.old ;
	  svc_enable lightdm ;;
esac
svc_enable $(basename `cat /etc/X11/default-display-manager`)
svc_enable display-manager
#systemctl set-default graphical.target ; sleep 3
chmod 1777 /tmp

# enable touchpad tapping
sed -i '/MatchIsTouchpad/a \ \ \ \ \ \ \ \ Option "Tapping" "on"' \
  /usr/share/X11/xorg.conf.d/10-evdev.conf
sed -i '/MatchIsTouchpad/a \ \ \ \ \ \ \ \ Option "Tapping" "on"' \
  /usr/share/X11/xorg.conf.d/40-libinput.conf
## ??? egrep -i 'synap|alps|etps|elan' /proc/bus/input/devices
#libinput list-devices ; xinput --list
#xinput list-props XX [; xinput disable YY] # by id, list-props or disable
#xinput set-prop <deviceid|devicename> <deviceproperty> <value>

# update XDG user dir config
export LANG=en_US.UTF-8 ; export CHARSET=UTF-8
echo 'BIN=bin' >> /etc/xdg/user-dirs.defaults
xdg-user-dirs-update ; sleep 3

sed -i 's|nomodeset | |' /etc/default/grub
sed -i 's|text | |' /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg
