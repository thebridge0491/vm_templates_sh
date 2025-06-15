#!/bin/sh -eux

## scripts/userifc.sh
export CHOICE_DESKTOP=${1:-xfce}
set +e

pkgin update

read -p "Fetch missing distribution sets? Enter 'y' to continue [yN]: " response
if [ "y" = "${response}" ] || [ "Y" = "${response}" ] ; then
  # fetch missing distribution sets like: xbase.tar.xz
  # uname_m: [amd64 | arm64] ; rel: X.Y
  uname_m=$(uname -m) ; rel=$(sysctl -n kern.osrelease) ;
  cd /tmp ;
  for setX in xbase xserver xfont xetc ; do
    ftp http://cdn.netbsd.org/pub/NetBSD/NetBSD-${rel}/${uname_m}/binary/sets/${setX}.tar.xz ;
    tar -C / -xpJf ${setX}.tar.xz ;
  done ;
fi

#pkgin -dy upgrade ; pkgin -y upgrade ; pkgin -y full-upgrade
. /root/scripts/distro_pkgs.ini
echo ${pkgs_displaysvr} ${pkgs_deskenv_${CHOICE_DESKTOP}}

read -p "Enter 'y' to continue [nY]: " response
#if [ "n" = "${response}" ] || [ "N" = "${response}" ] ; then
if [ -n "$(echo ${response} | grep -e '^[Nn].*')" ] ; then
  exit ;
fi
#pkgin [-d] -y install pkg0 .. pkgN # OK, skips missing
pkgin -y install ${pkgs_displaysvr} ${pkgs_deskenv_${CHOICE_DESKTOP}}
sleep 3


mkdir -p /var/run/dbus /var/db/dbus /var/run/xdm /var/lib/xdm \
  /usr/pkg/etc/xdm /usr/pkg/etc/xdg /usr/pkg/etc/X11/xorg.conf.d
for confX in 10-evdev.conf 40-libinput.conf ; do
  cp -an /usr/pkg/share/X11/xorg.conf.d/${confX} /usr/pkg/etc/X11/xorg.conf.d/ ;
done
for svc in dbus xdm ; do
  cp -a /usr/pkg/share/examples/rc.d/${svc} /etc/rc.d/ ;
done
cp -R /usr/pkg/share/examples/xdm /usr/pkg/etc/
for guiX in xfce4 lxqt ; do
  cp -R /usr/pkg/share/examples/${guiX} /usr/pkg/etc/xdg/ ;
done

groupadd -g 81 dbus
useradd -c 'System message bus' -u 81 -g dbus -d '/' -s /usr/bin/false dbus

# set video resolution ? gop 6: 1024x768x32
sed -i 's|;boot|;gop 6;boot|g' /boot.cfg

if [ -z "$(grep '^export XDG_DATA_DIRS=' /root/.xinitrc)" ] || [ -z "$(grep '^export XDG_CONFIG_DIRS=' /root/.xinitrc)" ] ; then
  cat >> /root/.xinitrc << EOF ;
export XDG_DATA_DIRS=/usr/pkg/share
export XDG_CONFIG_DIRS=/usr/pkg/etc/xdg

EOF
fi

if [ -z "$(grep '^ck-launch-session dbus-launch --exit-with-session' /root/.xinitrc)" ] ; then
  case ${CHOICE_DESKTOP} in
    lxqt) cat >> /root/.xinitrc << EOF ;
ck-launch-session dbus-launch --exit-with-session startlxqt

EOF
      ;;
    xfce) cat >> /root/.xinitrc << EOF ;
ck-launch-session dbus-launch --exit-with-session startxfce4

EOF
      ;;
  esac ;
  sleep 3 ;
fi

cp /root/.xinitrc /home/packer/.xinitrc
for pathX in /root /home/packer ; do
  (cd ${pathX} ; ln -s .xinitrc .xsession) ;
done
chown packer:$(id -gn packer) /home/packer/.xinitrc

# /usr/pkg/etc/X11/xorg.conf.d/20-[wsfb|intel|radeon].conf
sh -c 'cat > /usr/pkg/etc/X11/xorg.conf.d/20-wsfb.conf' << EOF
Section "Device"
  Identifier "Card0"
  Driver "wsfb" # wsfb | intel | radeon
  #BusID "PCI:0:2:0"
EndSection

EOF


#sh /root/init/common/misc_config.sh cfg_xdguserdirs /usr/pkg/etc/xdg
sh /root/init/common/misc_config.sh cfg_xdguserdirs /etc/xdg
sh /root/init/common/misc_config.sh cfg_xorgtouchpad /usr/pkg/etc/X11/xorg.conf.d

set +e ; set +u
echo "Enable|disable services" ; sleep 3
for svc in ${uiservices_enabled_${CHOICE_DESKTOP}} ; do
  if [ -z "$(service -e | grep ${svc})" ] ; then
    echo ${svc}=YES >> /etc/rc.conf ;
  fi ;
done
for svc in ${uiservices_disabled_${CHOICE_DESKTOP}} ; do
  if [ -n "$(service -e | grep ${svc})" ] ; then
    echo ${svc}=NO >> /etc/rc.conf ;
  fi ;
done


set +e
pkgin -y clean # #?? clean
