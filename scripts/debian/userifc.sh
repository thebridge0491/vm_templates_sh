#!/bin/sh -x

## scripts/userifc.sh
export CHOICE_DESKTOP=${1:-xfce}
set +e

snapshot_name=pre_userifc-$(date -u "+%Y%m%d") \
  sh $(dirname ${0})/upgradepkgs.sh snapshot

apt-config dump | grep -we Recommends -e Suggests | sed 's|1|0|' | \
  tee /etc/apt/apt.conf.d/999norecommends
# apt-get -o Acquire::ForceIPv4=true ...
echo '#Acquire::ForceIPv4 "true";' > /etc/apt/apt.conf.d/99force-ipv4

apt-get --allow-releaseinfo-change -y update
#apt-get --download-only -y upgrade ; apt-get -y upgrade
. /root/scripts/distro_pkgs.ini
echo ${pkgs_displaysvr} ${pkgs_deskenv_${CHOICE_DESKTOP}}

read -p "Enter 'y' to continue [nY]: " response
#if [ "n" = "${response}" ] || [ "N" = "${response}" ] ; then
if [ -n "$(echo ${response} | grep -e '^[Nn].*')" ] ; then
  exit ;
fi
#apt-get [--download-only] -y install pkg0 .. pkgN # ERR, doesn't skip missing
for pkgX in ${pkgs_displaysvr} ${pkgs_deskenv_${CHOICE_DESKTOP}} ; do
  apt-get --no-install-recommends -y install ${pkgX} ;
done


mkdir -p /etc/X11/xorg.conf.d
for confX in 10-evdev.conf 40-libinput.conf ; do
  cp -an /usr/share/X11/xorg.conf.d/${confX} /etc/X11/xorg.conf.d/ ;
done
if ! command -v systemctl > /dev/null ; then
  # Note, ex: dpkg-reconfigure lightdm
  # [/usr/[s]bin/[startxfce4 | startlxqt | lightdm | sddm | gdm3]
  update-alternatives --set x-session-manager $(cat /etc/X11/default-display-manager) ;
fi
sed -i -e 's|nomodeset ||g' -e 's|text ||g' -e 's|xdriver=vesa ||g' /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg


sh /root/init/common/misc_config.sh cfg_xdguserdirs /etc/xdg
sh /root/init/common/misc_config.sh cfg_xorgtouchpad /etc/X11/xorg.conf.d

set +e ; set +u
# service(s) enabled by package install trigger: dbus
echo "Enable|disable services" ; sleep 3
if command -v systemctl > /dev/null ; then
  systemctl set-default graphical.target ;
fi
for svc in ${uiservices_enabled_${CHOICE_DESKTOP}} ; do
  if command -v systemctl > /dev/null ; then
    systemctl unmask ${svc} || true ; systemctl enable ${svc} || true ;
  elif command -v sv > /dev/null ; then
    ln -s /etc/sv/${svc} /etc/service/ || true ;
  elif command -v rc-update > /dev/null ; then
    rc-update add ${svc} default || true ;
  elif command -v update-rc.d > /dev/null ; then
    update-rc.d ${svc} defaults || true ;
  fi ;
done
for svc in ${uiservices_disabled_${CHOICE_DESKTOP}} ; do
  if command -v systemctl > /dev/null ; then
    systemctl disable ${svc} || true ; systemctl mask ${svc} || true ;
  elif command -v sv > /dev/null ; then
    rm /var/service/${svc} || true ;
  elif command -v rc-update > /dev/null ; then
    rc-update del ${svc} default || true ;
  elif command -v update-rc.d > /dev/null ; then
    update-rc.d ${svc} remove || true ;
  fi ;
done


set +e
## scripts/cleanup.sh
apt-get -y clean
