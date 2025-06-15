#!/bin/sh -x

## scripts/userifc.sh
export CHOICE_DESKTOP=${1:-xfce}
set +e

snapshot_name=pre_userifc-$(date -u "+%Y%m%d") \
  sh $(dirname ${0})/upgradepkgs.sh snapshot

sed -i 's|.*solver.onlyRequires.*=.*|solver.onlyRequires = true|' \
  /etc/zypp/zypp.conf
sed -i 's|.*installRecommends.*=.*|installRecommends = no|' \
  /etc/zypp/zypper.conf
zypper --no-refresh --non-interactive remove netcat-openbsd

zypper --non-interactive refresh
#zypper --no-refresh --download-only --non-interactive update ; zypper --no-refresh --non-interactive update
. /root/scripts/distro_pkgs.ini
echo ${pkgs_displaysvr} ${pkgs_deskenv_${CHOICE_DESKTOP}}
r
ead -p "Enter 'y' to continue [nY]: " response
#if [ "n" = "${response}" ] || [ "N" = "${response}" ] ; then
if [ -n "$(echo ${response} | grep -e '^[Nn].*')" ] ; then
  exit ;
fi
#zypper --no-refresh --ignore-unknown [--download-only] --non-interactive install pkg0 .. pkgN # OK, skips missing
zypper --no-refresh --ignore-unknown --non-interactive install --no-recommends ${pkgs_displaysvr} ${pkgs_deskenv_${CHOICE_DESKTOP}}
sleep 3


mkdir -p /etc/X11/xorg.conf.d
for confX in 10-evdev.conf 40-libinput.conf ; do
  cp -an /usr/share/X11/xorg.conf.d/${confX} /etc/X11/xorg.conf.d/ ;
done
sed -i -e 's|nomodeset ||g' -e 's|text ||g' -e 's|xdriver=vesa ||g' /etc/default/grub
grub2-mkconfig -o /boot/grub2/grub.cfg


sh /root/init/common/misc_config.sh cfg_xdguserdirs /etc/xdg
sh /root/init/common/misc_config.sh cfg_xorgtouchpad /etc/X11/xorg.conf.d

set +e ; set +u
echo "Enable|disable services" ; sleep 3
systemctl set-default graphical.target
for svc in ${uiservices_enabled_${CHOICE_DESKTOP}} ; do
  systemctl unmask ${svc} ; systemctl enable ${svc} ;
done
for svc in ${uiservices_disabled_${CHOICE_DESKTOP}} ; do
  systemctl disable ${svc} ; systemctl mask ${svc} ;
done


set +e
## scripts/cleanup.sh
zypper --non-interactive clean
