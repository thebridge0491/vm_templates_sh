#!/bin/sh -eux

LANGS=${@:-py c java} ; export LANGS
set +e

. /root/scripts/distro_pkgs.ini

install_pkgs() {
  snapshot_name=pre_codelab-$(date -u "+%Y%m%d") \
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

  pacman -Syy --noconfirm
  #pacman -Suw --noconfirm ; pacman -Su --noconfirm
  for langX in ${LANGS} ; do
    #echo pkgs_lang_${langX}: ${pkgs_lang_${langX}} ;
    case ${langX} in
      py) echo pkgs_lang_${langX}: ${pkgs_lang_py} ;;
      c) echo pkgs_lang_${langX}: ${pkgs_lang_c} ;;
      java) echo pkgs_lang_${langX}: ${pkgs_lang_java} ;;
      scm) echo pkgs_lang_${langX}: ${pkgs_lang_scm} ;;
      hs) echo pkgs_lang_${langX}: ${pkgs_lang_hs} ;;
      scala) echo pkgs_lang_${langX}: ${pkgs_lang_scala} ;;
      ml) echo pkgs_lang_${langX}: ${pkgs_lang_ml} ;;
      lisp) echo pkgs_lang_${langX}: ${pkgs_lang_lisp} ;;
      cs) echo pkgs_lang_${langX}: ${pkgs_lang_cs} ;;
      groovy) echo pkgs_lang_${langX}: ${pkgs_lang_groovy} ;;
      go) echo pkgs_lang_${langX}: ${pkgs_lang_go} ;;
      clj) echo pkgs_lang_${langX}: ${pkgs_lang_clj} ;;
      fs) echo pkgs_lang_${langX}: ${pkgs_lang_fs} ;;
      rs) echo pkgs_lang_${langX}: ${pkgs_lang_rs} ;;
      rb) echo pkpkgs_lang_${langX}: ${pkgs_lang_rb} ;;
      swift) echo pkgs_lang_${langX}: ${pkgs_lang_swift} ;;
      *) echo pkgs_lang_${langX}: ${pkgs_lang_py} ;;
    esac ;
  done

  read -p "Enter 'y' to continue [nY]: " response
  #if [ "n" = "${response}" ] || [ "N" = "${response}" ] ; then
  if [ -n "$(echo ${response} | grep -e '^[Nn].*')" ] ; then
    exit ;
  fi
  for langX in ${LANGS} ; do
    case ${langX} in
      py) pkgs_var=${pkgs_lang_py} ;;
      c) pkgs_var=${pkgs_lang_c} ;;
      java) pkgs_var=${pkgs_lang_java} ;;
      scm) pkgs_var=${pkgs_lang_scm} ;;
      hs) pkgs_var=${pkgs_lang_hs} ;;
      scala) pkgs_var=${pkgs_lang_scala} ;;
      ml) pkgs_var=${pkgs_lang_ml} ;;
      lisp) pkgs_var=${pkgs_lang_lisp} ;;
      cs) pkgs_var=${pkgs_lang_cs} ;;
      groovy) pkgs_var=${pkgs_lang_groovy} ;;
      go) pkgs_var=${pkgs_lang_go} ;;
      clj) pkgs_var=${pkgs_lang_clj} ;;
      fs) pkgs_var=${pkgs_lang_fs} ;;
      rs) pkgs_var=${pkgs_lang_rs} ;;
      rb) pkgs_var=${pkgs_lang_rb} ;;
      swift) pkgs_var=${pkgs_lang_swift} ;;
      *) pkgs_var=${pkgs_lang_py} ;;
    esac ;
    #pacman --needed -S [-w] --noconfirm pkg0 .. pkgN # OK, skips missing ? 1 error only
    pacman --needed -S --noconfirm ${pkgs_var} ;
    #for pkgX in ${pkgs_var} ; do
    #  pacman --needed -S --noconfirm ${pkgX} ;
    #done ;
  done
}

config_sys() {
  if [ -n "$(java -version)" ] ; then
    #java_home=$(dirname $(dirname $(realpath $(which java)))) ;
    java_home=$(realpath $(which java) | sed "s:/bin/java::") ;
    #if [ -z "$(grep '^export JAVA_HOME' /etc/bash.bashrc)" ] ; then
    if [ -z "$(grep '^export JAVA_HOME' /etc/profile.d/jdk.sh)" ] ; then
      echo 'export JAVA_HOME=${java_home}' >> /etc/profile.d/jdk.sh ;
    fi ;
    chmod +x /etc/profile.d/jdk.sh ;
    #mkdir -p ${java_home} ;
    #java_version=$(java -version | head -n1 | sed 's|.*"\([0-9]*\.[0-9*]\)".*|\1|') ;
    #if [ -z "$(grep '^JAVA_VERSION' ${java_home}/release)" ] ; then
    #  echo JAVA_VERSION="${java_version}" >> ${java_home}/release ;
    #fi ;
    # PATH_TO_FX location varies: # try find javafx[-.]fxml*.jar
    #  [/usr/lib/jvm/java-[N]-openjfx|/opt/javafx-sdk-[N]]/lib: Arch Linux, Gluon download
    #  /usr/local/openjfx[N]/lib: FreeBSD
    #  /usr/share/openjfx: Debian
    found_jfxjar=$(find /usr /opt -name "javafx[-.]fxml*.jar" | head -n1) ;
    found_jfxjar=${found_jfxjar:-/usr/lib/jvm/java-11-openjfx/lib/javafx.fxml.jar} ;
    #if [ -z "$(grep '^export PATH_TO_FX' /etc/bash.bashrc)" ] ; then
    if [ -z "$(grep '^export PATH_TO_FX' /etc/profile.d/jdk.sh)" ] ; then
      echo "export PATH_TO_FX=$(dirname ${found_jfxjar})" >> /etc/profile.d/jdk.sh ;
    fi ;
  fi
  #archlinux-java status
  #archlinux-java set java-[11]-openjdk

  if command -v sv > /dev/null ; then
    echo "for runit service ops w/ Ansible,Saltstack" ; sleep 3
    ln -s /etc/runit/sv /etc/sv ;
    #ln -s /etc/runit/runsvdir/default /var/service ;
    ln -s /run/runit/service /var/service ;
  fi
  #. /etc/os-release
  #if [ ! -e /etc/os-release ] && [ -f /usr/lib/os-release ] ; then
  #  . /usr/lib/os-release ;
  #fi
}

toggle_svcs() {
  set +e ; set +u
  echo "Enable|disable services" ; sleep 3
  for svc in ${labservices_enabled} ; do
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
  for svc in ${labservices_disabled} ; do
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
