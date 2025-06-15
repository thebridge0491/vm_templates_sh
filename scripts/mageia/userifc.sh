#!/bin/sh -x

## scripts/userifc.sh
export CHOICE_DESKTOP=${1:-xfce}
set +e

snapshot_name=pre_userifc-$(date -u "+%Y%m%d") \
  sh $(dirname ${0})/upgradepkgs.sh snapshot

dnf --setopt=install_weak_deps=False config-manager --save
dnf config-manager --dump | grep -we install_weak_deps

##urpmi.update -a
dnf -y check-update
##urpmi --auto-update
#dnf -C --downloadonly -y upgrade ; dnf -C -y upgrade
. /root/scripts/distro_pkgs.ini
echo ${pkgs_displaysvr} ${pkgs_deskenv_${CHOICE_DESKTOP}}

read -p "Enter 'y' to continue [nY]: " response
#if [ "n" = "${response}" ] || [ "N" = "${response}" ] ; then
if [ -n "$(echo ${response} | grep -e '^[Nn].*')" ] ; then
  exit ;
fi
##urpmi [--no-install] pkg0 .. pkgN # ERR, doesn't skip missing
#dnf -C --skip-broken [--downloadonly] -y install pkg0 .. pkgN # OK, skips missing
dnf -C --skip-broken -y install ${pkgs_displaysvr} ${pkgs_deskenv_${CHOICE_DESKTOP}}
#for pkgX in ${pkgs_displaysvr} ${pkgs_deskenv_${CHOICE_DESKTOP}} ; do
#  ##urpmi --no-recommends ${pkgX} ;
#  dnf -C --setopt=install_weak_deps=False -y install ${pkgX} ;
#done
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
#urpmi --clean
dnf -y clean all ;
