#!/bin/sh -eux

## scripts/userifc.sh
export CHOICE_DESKTOP=${1:-lxqt}
set +e

. /root/scripts/distro_pkgs.ini
case ${CHOICE_DESKTOP} in
  xfce) pkgs_var=${pkgs_deskenv_xfce} ;
    uiservices_enabled=${uiservices_enabled_xfce} ;
    uiservices_disabled=${uiservices_disabled_xfce} ;;
  kde) pkgs_var=${pkgs_deskenv_kde} ;
    uiservices_enabled=${uiservices_enabled_kde} ;
    uiservices_disabled=${uiservices_disabled_kde} ;;
  lxqt|*) pkgs_var=${pkgs_deskenv_lxqt} ;
    uiservices_enabled=${uiservices_enabled_lxqt} ;
    uiservices_disabled=${uiservices_disabled_lxqt} ;;
esac

install_pkgs() {
  snapshot_name=pre_userifc-$(date -u "+%Y%m%d") \
    sh $(dirname ${0})/upgradepkgs.sh snapshot

  pkg update

  #distrosets="src ports" sh $(dirname ${0})/upgradepkgs.sh fetch_distrosets

  #pkg upgrade --fetch-only -Uy ; pkg upgrade -Uy
  #echo pkgs_deskenv_${CHOICE_DESKTOP}: ${pkgs_deskenv_${CHOICE_DESKTOP}}
  echo pkgs_deskenv_${CHOICE_DESKTOP}: ${pkgs_var}

  read -p "Enter 'y' to continue [nY]: " response
  #if [ "n" = "${response}" ] || [ "N" = "${response}" ] ; then
  if [ -n "$(echo ${response} | grep -e '^[Nn].*')" ] ; then
    exit ;
  fi
  #pkg install [--fetch-only] -Uy pkg0 .. pkgN # ERR, doesn't skip missing
  for pkgX in ${pkgs_var} ; do
    pkg install -Uy ${pkgX} ;
  done
}

config_sys() {
  #if [ "$(dmesg | grep -iE 'kvm|qemu|hypervisor')" ] ; then
  if [ ! "none" = "$(sysctl -n kern.vm_guest)" ] ; then
    sysrc -f /boot/loader.conf utouch_load="YES" ;
  else
    sysrc wpa_supplicant_program="/usr/local/sbin/wpa_supplicant" ;
    sysrc kld_list+=i915kms ; # i915kms | amdgpu
  fi

  if [ -z "$(grep '^kern.vty=' /boot/loader.conf)" ] || [ -z "$(grep '^hw.psm.synaptics_support=' /boot/loader.conf)" ] ; then
    sh -c 'cat >> /boot/loader.conf' << EOF
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

  #if [ -z "$(grep '^setenv QT_QPA_PLATFORM' /etc/csh.cshrc)" ] ; then
  if [ -z "$(grep '^export QT_QPA_PLATFORM' /etc/profile.d/qt_qpa.sh)" ] ; then
    echo 'export QT_QPA_PLATFORM="wayland;xcb"' >> /etc/profile.d/qt_qpa.sh ;
    chmod +x /etc/profile.d/qt_qpa.sh ;
  fi
  #if [ -z "$(grep '^setenv GDK_BACKEND' /etc/csh.cshrc)" ] ; then
  if [ -z "$(grep '^export GDK_BACKEND' /etc/profile.d/gdk_backend.sh)" ] ; then
    echo 'export GDK_BACKEND="wayland;x11"' >> /etc/profile.d/gdk_backend.sh ;
    chmod +x /etc/profile.d/gdk_backend.sh ;
  fi
  sh /root/init/common/misc_config.sh cfg_xdguserdirs /usr/local/etc/xdg

  if [ -e /usr/local/share/X11/xorg.conf.d ] ; then
    mkdir -p /usr/local/etc/X11/xorg.conf.d ;
    for confX in 10-evdev.conf 40-libinput.conf ; do
      cp -an /usr/local/share/X11/xorg.conf.d/${confX} /usr/local/etc/X11/xorg.conf.d/ ;
    done ;

    #if [ "$(dmesg | grep -iE 'kvm|qemu|hypervisor')" ] ; then
    if [ ! "none" = "$(sysctl -n kern.vm_guest)" ] ; then
      sh -c 'cat > /usr/local/etc/X11/xorg.conf.d/20-scfb.conf' << EOF
Section "Device"
  Identifier "Card0"
  Driver "scfb"
  #BusID "PCI:0:2:0"
EndSection

EOF
    else
      ## /usr/local/etc/X11/xorg.conf.d/20-[intel|radeon|scfb].conf
      sh -c 'cat > /usr/local/etc/X11/xorg.conf.d/20-intel.conf' << EOF
#Section "Device"
#  Identifier "Card0"
#  Driver "intel" # intel | radeon | scfb
#  #BusID "PCI:0:2:0"
#EndSection

EOF
    fi ;
    sh -c 'cat > /usr/local/etc/X11/xorg.conf.d/10-modesetting.conf' << EOF
#Section "Device"
#  Identifier "Card0"
#  Driver "modesetting"
#  #BusID "PCI:0:2:0"
#EndSection

EOF

    sh /root/init/common/misc_config.sh cfg_xorgtouchpad /usr/local/etc/X11/xorg.conf.d ;
  fi
}

toggle_svcs() {
  set +e ; set +u
  echo "Enable|disable services" ; sleep 3
  for svc in ${uiservices_enabled} ; do
    sysrc ${svc}_enable="YES" ;
  done
  for svc in ${uiservices_disabled} ; do
    sysrc ${svc}_enable="NO" ;
  done

  set +e
  ## scripts/cleanup.sh
  ASSUME_ALWAYS_YES=yes pkg clean -y
  if command -v portmaster > /dev/null ; then
    portmaster -a ; portmaster -n --clean-distfiles ;
  fi
}

run_all() {
  install_pkgs
  config_sys
  toggle_svcs
}

#----------------------------------------
${@:-run_all}
