#!/bin/sh -eux

## scripts/userifc.sh
export CHOICE_DESKTOP=${1:-xfce}
set +e

read -p "Fetch missing distribution sets? Enter 'y' to continue [yN]: " response
if [ "y" = "${response}" ] || [ "Y" = "${response}" ] ; then
  # fetch missing distribution sets like: xbase*.tgz
  # arch_s: [amd64 | arm64] ; rel: X.Y
  arch_s=$(arch -s) ; rel=$(sysctl -n kern.osrelease) ;
  setVer=$(sysctl -n kern.osrelease | tr '.' '\0') ;
  cd /tmp ;
  for setX in xbase xserv xfont xshare ; do
    ftp http://cdn.openbsd.org/pub/OpenBSD/${rel}/${arch_s}/${setX}${setVer}.tgz ;
    tar -C / -xpzf ${setX}${setVer}.tgz ;
  done ;

  sysmerge ;
fi

#pkg_add -n -u ; pkg_add -u
. /root/scripts/distro_pkgs.ini
echo ${pkgs_displaysvr} ${pkgs_deskenv_${CHOICE_DESKTOP}}

read -p "Enter 'y' to continue [nY]: " response
#if [ "n" = "${response}" ] || [ "N" = "${response}" ] ; then
if [ -n "$(echo ${response} | grep -e '^[Nn].*')" ] ; then
  exit ;
fi
#pkg_add [-n] -ziU pkg0-- .. pkgN-- # OK, skips missing
pkg_add -ziU ${pkgs_displaysvr} ${pkgs_deskenv_${CHOICE_DESKTOP}}
sleep 3


if [ -z "$(grep -e 'dbus-uuidgen --ensure' /etc/rc.local)" ] ; then
  #echo /usr/local/bin/dbus-uuidgen --ensure=/etc/machine-id >> /etc/rc.local ;
  echo /usr/local/bin/dbus-uuidgen --ensure >> /etc/rc.local ;
  chmod +x /etc/rc.local ;
fi
mkdir -p /etc/X11/xorg.conf.d
#for confX in 10-evdev.conf 40-libinput.conf ; do
#  cp -an /usr/local/share/X11/xorg.conf.d/${confX} /etc/X11/xorg.conf.d/ ;
#done

if [ -z "$(grep '^export XDG_CONFIG_HOME=' /etc/rc.local)" ] ; then
  echo 'export XDG_CONFIG_HOME=/etc/xdg' >> /etc/rc.local ;
fi
if [ -z "$(grep '^machdep.allowaperture=.*' /etc/sysctl.conf)" ] ; then
  echo 'machdep.allowaperture=2' >> /etc/sysctl.conf ;
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


sh /root/init/common/misc_config.sh cfg_xdguserdirs /etc/xdg
sh /root/init/common/misc_config.sh cfg_xorgtouchpad /etc/X11/xorg.conf.d

set +e ; set +u
echo "Enable|disable services" ; sleep 3
for svc in ${uiservices_enabled_${CHOICE_DESKTOP}} ; do
  rcctl enable ${svc} ;
done
for svc in ${uiservices_disabled_${CHOICE_DESKTOP}} ; do
  rcctl disable ${svc} ;
done


set +e
# #?? clean
