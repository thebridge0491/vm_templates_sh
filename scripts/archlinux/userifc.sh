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

  if command -v systemctl > /dev/null ; then
    systemctl stop pamac.service ;
  elif command -v s6-rc > /dev/null ; then
    s6-rc -d change pamac ;
  elif command -v sv > /dev/null ; then
    sv down pamac ;
  elif command -v rc-update > /dev/null ; then
    rc-service pamac stop ;
  fi
  rm /var/lib/pacman/db.lck

  pacman --noconfirm -Syy
  #pacman -Suw --noconfirm ; pacman -Su --noconfirm
  #echo pkgs_deskenv_${CHOICE_DESKTOP}: ${pkgs_deskenv_${CHOICE_DESKTOP}}
  echo pkgs_deskenv_${CHOICE_DESKTOP}: ${pkgs_var}

  read -p "Enter 'y' to continue [nY]: " response
  #if [ "n" = "${response}" ] || [ "N" = "${response}" ] ; then
  if [ -n "$(echo ${response} | grep -e '^[Nn].*')" ] ; then
    exit ;
  fi
  #pacman --needed -S [-w] --noconfirm pkg0 .. pkgN # OK, skips missing ? 1 error only
  pacman --needed -S --noconfirm ${pkgs_var}
  #for pkgX in ${pkgs_var} ; do
  #  pacman --needed -S --noconfirm ${pkgs_var} ;
  #done
}

config_sys() {
  if command -v sv > /dev/null ; then
    echo "for runit service ops w/ Ansible,Saltstack" ; sleep 3
    ln -s /etc/runit/sv /etc/sv ;
    #ln -s /etc/runit/runsvdir/default /var/service ;
    ln -s /run/runit/service /var/service ;
  fi
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
    #. /etc/os-release ;
    #if [ ! -e /etc/os-release ] && [ -f /usr/lib/os-release ] ; then
    #  . /usr/lib/os-release ;
    #fi ;
    if ! command -v systemctl > /dev/null ; then
      if [ 'lxqt' = "${CHOICE_DESKTOP}" ] || [ 'kde' = "${CHOICE_DESKTOP}" ] ; then
        sed -i "s|DISPLAYMANAGER=.*|DISPLAYMANAGER='sddm'|" /etc/conf.d/xdm ;
      else #elif [ 'xfce' = "${CHOICE_DESKTOP}" ] ; then
        sed -i "s|DISPLAYMANAGER=.*|DISPLAYMANAGER='gdm'|" /etc/conf.d/xdm ;
      fi ;
    fi ;

    sh -c 'cat > etc/X11/xorg.conf.d/10-modesetting.conf' << EOF
#Section "Device"
#  Identifier "GPU0"
#  Driver "modesetting"
#  #BusID "PCI:0:2:0"
#EndSection

EOF

    sh /root/init/common/misc_config.sh cfg_xorgtouchpad /etc/X11/xorg.conf.d ;
  fi

  sed -i -e 's|nomodeset ||g' -e 's|text ||g' -e 's|xdriver=vesa ||g' /etc/default/grub
  grub-mkconfig -o /boot/grub/grub.cfg
}

toggle_svcs() {
  set +e ; set +u
  echo "Enable|disable services" ; sleep 3
  if command -v systemctl > /dev/null ; then
    systemctl set-default graphical.target ;
  fi
  for svc in ${uiservices_enabled} ; do
    if command -v systemctl > /dev/null ; then
      systemctl unmask ${svc} || true ; systemctl enable ${svc} || true ;
    elif command -v s6-rc > /dev/null ; then
      s6-rc-bundle-update add default ${svc} || true ;
      s6-rc-bundle -c /etc/s6/rc/compiled add default ${svc} || true ;
    elif command -v sv > /dev/null ; then
      ln -s /etc/runit/sv/${svc} /etc/runit/runsvdir/default/ || true ;
      #ln -s /etc/runit/sv/${svc} /run/runit/service/ || true ;
    elif command -v rc-update > /dev/null ; then
      rc-update add ${svc} default || true ;
    fi ;
  done
  for svc in ${uiservices_disabled} ; do
    if command -v systemctl > /dev/null ; then
      systemctl disable ${svc} || true ; systemctl mask ${svc} || true ;
    elif command -v s6-rc > /dev/null ; then
      #s6-rc -d change ${svc} || true ;
      s6-rc-bundle-update delete default ${svc} || true ;
    elif command -v sv > /dev/null ; then
      rm /etc/runit/runsvdir/default/${svc} || true ;
      #rm /run/runit/service/${svc} || true ;
    elif command -v rc-update > /dev/null ; then
      rc-update del ${svc} default || true ;
    fi ;
  done

  set +e
  ## scripts/cleanup.sh
  pacman -Sc --noconfirm
}

run_all() {
  install_pkgs
  config_sys
  toggle_svcs
}

#----------------------------------------
${@:-run_all}
