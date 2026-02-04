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
  #distrosets="xbase xserv xfont xshare" sh $(dirname ${0})/upgradepkgs.sh fetch_distrosets

  #pkg_add -n -u ; pkg_add -u
  #echo pkgs_deskenv_${CHOICE_DESKTOP}: ${pkgs_deskenv_${CHOICE_DESKTOP}}
  echo pkgs_deskenv_${CHOICE_DESKTOP}: ${pkgs_var}

  read -p "Enter 'y' to continue [nY]: " response
  #if [ "n" = "${response}" ] || [ "N" = "${response}" ] ; then
  if [ -n "$(echo ${response} | grep -e '^[Nn].*')" ] ; then
    exit ;
  fi
  #pkg_add [-n] -ziU pkg0-- .. pkgN-- # OK, skips missing
  pkg_add -ziU ${pkgs_var}
  sleep 3
}

config_sys() {
  if [ -z "$(grep -e 'dbus-uuidgen --ensure' /etc/rc.local)" ] ; then
    #echo /usr/local/bin/dbus-uuidgen --ensure=/etc/machine-id >> /etc/rc.local ;
    echo /usr/local/bin/dbus-uuidgen --ensure >> /etc/rc.local ;
    chmod +x /etc/rc.local ;
  fi
  if [ -z "$(grep '^machdep.allowaperture=.*' /etc/sysctl.conf)" ] ; then
    echo 'machdep.allowaperture=2' >> /etc/sysctl.conf ;
  fi
  if [ -z "$(grep '^export XDG_CONFIG_HOME=' /etc/rc.local)" ] ; then
    echo 'export XDG_CONFIG_HOME=/etc/xdg' >> /etc/rc.local ;
  fi

  mkdir -p /etc/profile.d
  if [ ! -e /etc/profile ] ; then
    cat << EOF > /etc/profile ;
if [ -d /etc/profile.d ] ; then
  for i in /etc/profile.d/*.sh ; do
    if [ -r "${i}" ] ; then
      . "${i}" ;
    fi ;
  done ;
  unset i ;
fi

EOF
    chmod +x /etc/profile ;
  fi
  #if [ -z "$(grep '^export QT_QPA_PLATFORM' /etc/ksh.kshrc)" ] ; then
  if [ -z "$(grep '^export QT_QPA_PLATFORM' /etc/profile.d/qt_qpa.sh)" ] ; then
    echo 'export QT_QPA_PLATFORM="wayland;xcb"' >> /etc/profile.d/qt_qpa.sh ;
    chmod +x /etc/profile.d/qt_qpa.sh ;
  fi
  #if [ -z "$(grep '^export GDK_BACKEND' /etc/ksh.kshrc)" ] ; then
  if [ -z "$(grep '^export GDK_BACKEND' /etc/profile.d/gdk_backend.sh)" ] ; then
    echo 'export GDK_BACKEND="wayland;x11"' >> /etc/profile.d/gdk_backend.sh ;
    chmod +x /etc/profile.d/gdk_backend.sh ;
  fi
  sh /root/init/common/misc_config.sh cfg_xdguserdirs /etc/xdg

  mkdir -p /etc/X11/xorg.conf.d
  if [ -e /usr/local/share/X11/xorg.conf.d ] ; then
    #for confX in 10-evdev.conf 40-libinput.conf ; do
    #  cp -an /usr/local/share/X11/xorg.conf.d/${confX} /etc/X11/xorg.conf.d/ ;
    #done

    sh /root/init/common/misc_config.sh cfg_xorgtouchpad /etc/X11/xorg.conf.d ;
  fi

  # /etc/X11/xorg.conf.d/20-[wsfb|intel|radeon].conf
  sh -c 'cat > /etc/X11/xorg.conf.d/20-wsfb.conf' << EOF
Section "Device"
  Identifier "Card0"
  Driver "wsfb" # wsfb | intel | radeon
  #BusID "PCI:0:2:0"
EndSection

EOF
  sh -c 'cat > /etc/X11/xorg.conf.d/10-modesetting.conf' << EOF
#Section "Device"
#  Identifier "Card0"
#  Driver "modesetting"
#  #BusID "PCI:0:2:0"
#EndSection

EOF

  if [ -z "$(grep '^ck-launch-session dbus-launch --exit-with-session' /root/.xinitrc)" ] ; then
    case ${CHOICE_DESKTOP} in
      xfce) cat >> /root/.xinitrc << EOF ;
ck-launch-session dbus-launch --exit-with-session startxfce4

EOF
        ;;
      kde) cat >> /root/.xinitrc << EOF ;
#ck-launch-session dbus-launch --exit-with-session startkde
ck-launch-session dbus-launch --exit-with-session startplasma-x11

EOF
        ;;
      lxqt) cat >> /root/.xinitrc << EOF ;
ck-launch-session dbus-launch --exit-with-session startlxqt

EOF
        ;;
    esac ;
    sleep 3 ;
  fi

  cp /root/.xinitrc /home/packer/
  for pathX in /root /home/packer ; do
    (cd ${pathX} ; ln -s .xinitrc .xsession) ;
  done
  chown packer:$(id -gn packer) /home/packer/.xinitrc
}

toggle_svcs() {
  set +e ; set +u
  echo "Enable|disable services" ; sleep 3
  for svc in ${uiservices_enabled} ; do
    rcctl enable ${svc} ;
  done
  for svc in ${uiservices_disabled} ; do
    rcctl disable ${svc} ;
  done

  set +e
  # #?? clean
}

run_all() {
  install_pkgs
  config_sys
  toggle_svcs
}

#----------------------------------------
${@:-run_all}
