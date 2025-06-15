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
# apt-get -o Acquire::Retries=3 ...
echo 'Acquire::Retries "3";' > /etc/apt/apt.conf.d/99retries03

# fix AND re-attempt install for infrequent errors
apt-get -y update ; apt-get --fix-broken -y install
#apt-get -y dist-upgrade
. /root/scripts/distro_pkgs.ini
echo ${pkgs_displaysvr} ${pkgs_deskenv_${CHOICE_DESKTOP}}

read -p "Enter 'y' to continue [nY]: " response
#if [ "n" = "${response}" ] || [ "N" = "${response}" ] ; then
if [ -n "$(echo ${response} | grep -e '^[Nn].*')" ] ; then
  exit ;
fi
#apt-get [--simulate] -y install pkg0 .. pkgN # ERR, doesn't skip missing
for pkgX in ${pkgs_displaysvr} ${pkgs_deskenv_${CHOICE_DESKTOP}} ; do
  apt-get -y install ${pkgX} ;
done
sleep 3


mkdir -p /etc/X11/xorg.conf.d
for confX in 10-evdev.conf 40-libinput.conf ; do
  cp -an /usr/share/X11/xorg.conf.d/${confX} /etc/X11/xorg.conf.d/ ;
done
touch /etc/system-release
sed -i -e 's|nomodeset ||g' -e 's|text ||g' -e 's|xdriver=vesa ||g' /etc/default/grub
#sed -i -e 's|noacpi ||g' /etc/default/grub
grub2-mkconfig -o /boot/grub2/grub.cfg

XFdrake --auto
#drakx11 ; sleep 5 ; drakdm ; sleep 5 ; drakboot ; sleep 5
mv /etc/X11/xorg.conf /etc/X11/xorg.conf.bak || true


sh /root/init/common/misc_config.sh cfg_xdguserdirs /etc/xdg
sh /root/init/common/misc_config.sh cfg_xorgtouchpad /etc/X11/xorg.conf.d

set +e ; set +u
echo "Enable|disable services" ; sleep 3
for svc in ${uiservices_enabled_${CHOICE_DESKTOP}} ; do
  chkconfig --add ${svc} || true ;
done
for svc in ${uiservices_disabled_${CHOICE_DESKTOP}} ; do
  chkconfig --del ${svc} || true ;
done


set +e
## scripts/cleanup.sh
apt-get -y clean
