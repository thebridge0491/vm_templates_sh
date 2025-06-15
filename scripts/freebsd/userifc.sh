#!/bin/sh -eux

## scripts/userifc.sh
export CHOICE_DESKTOP=${1:-xfce}
set +e

snapshot_name=pre_userifc-$(date -u "+%Y%m%d") \
  sh $(dirname ${0})/upgradepkgs.sh snapshot

if command -v aria2c > /dev/null ; then
  FETCH_CMD=${FETCH_CMD:-aria2c} ;
fi

pkg update
#pkg upgrade --fetch-only -Uy ; pkg upgrade -Uy
. /root/scripts/distro_pkgs.ini
echo ${pkgs_displaysvr} ${pkgs_deskenv_${CHOICE_DESKTOP}}

read -p "Enter 'y' to continue [nY]: " response
#if [ "n" = "${response}" ] || [ "N" = "${response}" ] ; then
if [ -n "$(echo ${response} | grep -e '^[Nn].*')" ] ; then
  exit ;
fi
#pkg install [--fetch-only] -Uy pkg0 .. pkgN # ERR, doesn't skip missing
for pkgX in ${pkgs_displaysvr} ${pkgs_deskenv_${CHOICE_DESKTOP}} ; do
  pkg install -Uy ${pkgX} ;
done


mkdir -p /usr/local/etc/X11/xorg.conf.d
for confX in 10-evdev.conf 40-libinput.conf ; do
  cp -an /usr/local/share/X11/xorg.conf.d/${confX} /usr/local/etc/X11/xorg.conf.d/ ;
done
sysrc wpa_supplicant_progam="/usr/local/sbin/wpa_supplicant"
sysrc kld_list+=i915kms # i915kms | amdgpu

# config xorg
if [ -z "$(grep '^kern.vty=' /boot/loader.conf)" ] || [ -z "$(grep '^hw.psm.synaptics_support=' /boot/loader.conf)" ] ; then
  sh -c 'cat >> /boot/loader.conf' << EOF
#exec="gop set 3"
#exec="mode 3"
kern.vty=vt
hw.psm.synaptics_support="1"

EOF
fi
if [ -z "$(grep '^LANG=' /etc/profile.conf)" ] ; then
  sh -c 'cat >> /etc/profile.conf' << EOF
LANG=en_US.UTF-8 ; export LANG

EOF
fi
if [ -z "$(grep '^CHARSET=' /etc/profile.conf)" ] ; then
  sh -c 'cat >> /etc/profile.conf' << EOF
CHARSET=UTF-8 ; export CHARSET

EOF
fi

## /usr/local/etc/X11/xorg.conf.d/20-[intel|radeon|scfb].conf
#sh -c 'cat > /usr/local/etc/X11/xorg.conf.d/20-intel.conf' << EOF
#Section "Device"
#  Identifier "Card0"
#  Driver "intel" # intel | radeon | scfb
#  #BusID "PCI:0:2:0"
#EndSection
#
#EOF


sh /root/init/common/misc_config.sh cfg_xdguserdirs /usr/local/etc/xdg
sh /root/init/common/misc_config.sh cfg_xorgtouchpad /usr/local/etc/X11/xorg.conf.d

set +e ; set +u
echo "Enable|disable services" ; sleep 3
for svc in ${uiservices_enabled_${CHOICE_DESKTOP}} ; do
  sysrc ${svc}_enable="YES" ;
done
for svc in ${uiservices_disabled_${CHOICE_DESKTOP}} ; do
  sysrc ${svc}_enable="NO" ;
done

set +e
## scripts/cleanup.sh
ASSUME_ALWAYS_YES=yes pkg clean -y
if command -v portmaster > /dev/null ; then
  portmaster -a ; portmaster -n --clean-distfiles ;
fi
