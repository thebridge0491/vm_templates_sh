#!/bin/sh -x

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

  apt-config dump | grep -we Recommends -e Suggests | sed 's|1|0|' | \
    tee /etc/apt/apt.conf.d/999norecommends
  # apt-get -o Acquire::ForceIPv4=true ...
  echo '#Acquire::ForceIPv4 "true";' > /etc/apt/apt.conf.d/99force-ipv4
  # apt-get -o Acquire::Retries=3 ...
  echo 'Acquire::Retries "3";' > /etc/apt/apt.conf.d/99retries03

  # fix AND re-attempt install for infrequent errors
  apt-get -y update ; apt-get --fix-broken -y install
  #apt-get -y dist-upgrade
  #echo pkgs_deskenv_${CHOICE_DESKTOP}: ${pkgs_deskenv_${CHOICE_DESKTOP}}
  echo pkgs_deskenv_${CHOICE_DESKTOP}: ${pkgs_var}

  read -p "Enter 'y' to continue [nY]: " response
  #if [ "n" = "${response}" ] || [ "N" = "${response}" ] ; then
  if [ -n "$(echo ${response} | grep -e '^[Nn].*')" ] ; then
    exit ;
  fi
  #apt-get [--simulate] -y install pkg0 .. pkgN # ERR, doesn't skip missing
  for pkgX in ${pkgs_var} ; do
    apt-get -y install ${pkgX} ;
  done
  sleep 3
}

config_sys() {
  #if [ -z "$(grep '^export QT_QPA_PLATFORM' /etc/bash.bashrc)" ] ; then
  if [ -z "$(grep '^export QT_QPA_PLATFORM' /etc/profile.d/qt_qpa.sh)" ] ; then
    echo 'export QT_QPA_PLATFORM="wayland;xcb"' >> /etc/profile.d/qt_qpa.sh ;
    chmod +x /etc/profile.d/qt_qpa.sh ;
  fi
  #if [ -z "$(grep '^export GDK_BACKEND' /etc/bash.bashrc)" ] ; then
  if [ -z "$(grep '^export GDK_BACKEND' /etc/profile.d/gdk_backend.sh)" ] ; then
    echo 'export GDK_BACKEND="wayland;x11"' >> /etc/profile.d/gdk_backend.sh ;
    chmod +x /etc/profile.d/gdk_backend.sh ;
  fi
  sh /root/init/common/misc_config.sh cfg_xdguserdirs /etc/xdg

  if [ -e /usr/share/X11/xorg.conf.d ] ; then
    mkdir -p /etc/X11/xorg.conf.d ;
    for confX in 10-evdev.conf 40-libinput.conf ; do
      cp -an /usr/share/X11/xorg.conf.d/${confX} /etc/X11/xorg.conf.d/ ;
    done ;

    sh -c 'cat > etc/X11/xorg.conf.d/10-modesetting.conf' << EOF
#Section "Device"
#  Identifier "Device0"
#  Driver "modesetting"
#  #BusID "PCI:0:2:0"
#EndSection

EOF

    XFdrake --auto ;
    #drakx11 ; sleep 5 ; drakdm ; sleep 5 ; drakboot ; sleep 5 ;
    mv /etc/X11/xorg.conf /etc/X11/xorg.conf.bak || true ;

    sh /root/init/common/misc_config.sh cfg_xorgtouchpad /etc/X11/xorg.conf.d ;
  fi

  touch /etc/system-release
  sed -i -e 's|nomodeset ||g' -e 's|text ||g' -e 's|xdriver=vesa ||g' /etc/default/grub
  #sed -i -e 's|noacpi ||g' /etc/default/grub
  grub2-mkconfig -o /boot/grub2/grub.cfg
}

toggle_svcs() {
  set +e ; set +u
  echo "Enable|disable services" ; sleep 3
  for svc in ${uiservices_enabled} ; do
    chkconfig --add ${svc} || true ;
  done
  for svc in ${uiservices_disabled} ; do
    chkconfig --del ${svc} || true ;
  done

  set +e
  ## scripts/cleanup.sh
  apt-get -y clean
}

run_all() {
  install_pkgs
  config_sys
  toggle_svcs
}

#----------------------------------------
${@:-run_all}
