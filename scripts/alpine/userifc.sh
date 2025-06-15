#!/bin/sh -x

## scripts/userifc.sh
export CHOICE_DESKTOP=${1:-xfce}
set +e

snapshot_name=pre_userifc-$(date -u "+%Y%m%d") \
  sh $(dirname ${0})/upgradepkgs.sh snapshot

apk update ; apk fix
#apk upgrade
. /root/scripts/distro_pkgs.ini
echo ${pkgs_displaysvr} ${pkgs_deskenv_${CHOICE_DESKTOP}}

read -p "Enter 'y' to continue [nY]: " response
#if [ "n" = "${response}" ] || [ "N" = "${response}" ] ; then
if [ -n "$(echo ${response} | grep -e '^[Nn].*')" ] ; then
  exit ;
fi
setup-xorg-base
#apk [fetch | add] pkg0 .. pkgN # ERR, doesn't skip missing
for pkgX in ${pkgs_displaysvr} ${pkgs_deskenv_${CHOICE_DESKTOP}} ; do
  apk add ${pkgX} ;
done


mkdir -p /etc/X11/xorg.conf.d
for confX in 10-evdev.conf 40-libinput.conf ; do
  cp -an /usr/share/X11/xorg.conf.d/${confX} /etc/X11/xorg.conf.d/ ;
done
sed -i -e 's|nomodeset ||g' -e 's|text ||g' -e 's|xdriver=vesa ||g' /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg


sh /root/init/common/misc_config.sh cfg_xdguserdirs /etc/xdg
sh /root/init/common/misc_config.sh cfg_xorgtouchpad /etc/X11/xorg.conf.d

set +e ; set +u
echo "Enable|disable services" ; sleep 3
for svc in ${uiservices_enabled_${CHOICE_DESKTOP}} ; do
  rc-update add ${svc} default || true ;
done
for svc in ${uiservices_disabled_${CHOICE_DESKTOP}} ; do
  rc-update del ${svc} default || true ;
done


set +e
## scripts/cleanup.sh
apk -v cache clean
