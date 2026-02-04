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
  pkgin update

  #distrosets="xbase xserver xfont xetc" sh $(dirname ${0})/upgradepkgs.sh fetch_distrosets

  #pkgin -dy upgrade ; pkgin -y upgrade ; pkgin -y full-upgrade
  #echo pkgs_deskenv_${CHOICE_DESKTOP}: ${pkgs_deskenv_${CHOICE_DESKTOP}}
  echo pkgs_deskenv_${CHOICE_DESKTOP}: ${pkgs_var}

  read -p "Enter 'y' to continue [nY]: " response
  #if [ "n" = "${response}" ] || [ "N" = "${response}" ] ; then
  if [ -n "$(echo ${response} | grep -e '^[Nn].*')" ] ; then
    exit ;
  fi
  #pkgin [-d] -y install pkg0 .. pkgN # OK, skips missing
  pkgin -y install ${pkgs_var}
  sleep 3
}

config_sys() {
  # set video resolution ? gop 6: 1024x768x32
  sed -i 's|;boot|;gop 6;boot|g' /boot.cfg

  groupadd -g 81 dbus
  useradd -c 'System message bus' -u 81 -g dbus -d '/' -s /usr/bin/false dbus

  mkdir -p /var/run/dbus /var/db/dbus /var/run/xdm /var/lib/xdm \
    /usr/pkg/etc/xdm /usr/pkg/etc/xdg

  for svc in dbus xdm ; do
    cp -a /usr/pkg/share/examples/rc.d/${svc} /etc/rc.d/ ;
  done
  cp -R /usr/pkg/share/examples/xdm /usr/pkg/etc/

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
  #sh /root/init/common/misc_config.sh cfg_xdguserdirs /usr/pkg/etc/xdg
  sh /root/init/common/misc_config.sh cfg_xdguserdirs /etc/xdg

  mkdir -p /usr/pkg/etc/X11/xorg.conf.d
  if [ -e /usr/pkg/share/X11/xorg.conf.d ] ; then
    for guiX in xfce4 lxqt kde ; do
      cp -R /usr/pkg/share/examples/${guiX} /usr/pkg/etc/xdg/ ;
    done ;
    for confX in 10-evdev.conf 40-libinput.conf ; do
      cp -an /usr/pkg/share/X11/xorg.conf.d/${confX} /usr/pkg/etc/X11/xorg.conf.d/ ;
    done ;

    sh /root/init/common/misc_config.sh cfg_xorgtouchpad /usr/pkg/etc/X11/xorg.conf.d ;
  fi

  # /usr/pkg/etc/X11/xorg.conf.d/20-[wsfb|intel|radeon].conf
  sh -c 'cat > /usr/pkg/etc/X11/xorg.conf.d/20-wsfb.conf' << EOF
Section "Device"
  Identifier "Card0"
  Driver "wsfb" # wsfb | intel | radeon
  #BusID "PCI:0:2:0"
EndSection

EOF
  sh -c 'cat > /usr/pkc/etc/X11/xorg.conf.d/10-modesetting.conf' << EOF
#Section "Device"
#  Identifier "Card0"
#  Driver "modesetting"
#  #BusID "PCI:0:2:0"
#EndSection

EOF

  if [ -z "$(grep '^export XDG_DATA_DIRS=' /root/.xinitrc)" ] || [ -z "$(grep '^export XDG_CONFIG_DIRS=' /root/.xinitrc)" ] ; then
    cat >> /root/.xinitrc << EOF ;
export XDG_DATA_DIRS=/usr/pkg/share
export XDG_CONFIG_DIRS=/usr/pkg/etc/xdg

EOF
  fi

  if [ -z "$(grep '^ck-launch-session dbus-launch --exit-with-session' /root/.xinitrc)" ] ; then
    case ${CHOICE_DESKTOP} in
      xfce) cat >> /root/.xinitrc << EOF ;
ck-launch-session dbus-launch --exit-with-session startxfce4

EOF
        ;;
      kde) cat >> /root/.xinitrc << EOF ;
ck-launch-session dbus-launch --exit-with-session startkde

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
    if [ -z "$(service -e | grep ${svc})" ] ; then
      echo ${svc}=YES >> /etc/rc.conf ;
    fi ;
  done
  for svc in ${uiservices_disabled} ; do
    if [ -n "$(service -e | grep ${svc})" ] ; then
      echo ${svc}=NO >> /etc/rc.conf ;
    fi ;
  done

  set +e
  pkgin -y clean # #?? clean
}

run_all() {
  install_pkgs
  config_sys
  toggle_svcs
}

#----------------------------------------
${@:-run_all}
