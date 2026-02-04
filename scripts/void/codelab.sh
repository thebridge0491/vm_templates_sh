#!/bin/sh -eux

LANGS=${@:-py c java} ; export LANGS
set +e
#set -e

. /root/scripts/distro_pkgs.ini

install_pkgs() {
  snapshot_name=pre_codelab-$(date -u "+%Y%m%d") \
    sh $(dirname ${0})/upgradepkgs.sh snapshot

  xbps-install -S ; xbps-install -uy xbps
  #xbps-install -Duy ; xbps-install -uy
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
    #xbps-install [-D] -y pkg0 .. pkgN # ERR, doesn't skip missing
    for pkgX in ${pkgs_var} ; do
      xbps-install -y ${pkgX} ;
    done ;
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
  #xbps-alternatives --list [--group [jdk | python]]
  #xbps-alternatives --group jdk --set openjdk[11]
  #xbps-alternatives --group python --set python[3]


  if [ -z "$(grep -e 'dbus-uuidgen --ensure' /etc/rc.local)" ] ; then
    #echo /usr/bin/dbus-uuidgen --ensure=/etc/machine-id >> /etc/rc.local ;
    echo /usr/bin/dbus-uuidgen --ensure >> /etc/rc.local ;
    chmod +x /etc/rc.local ;
  fi
}

toggle_svcs() {
  set +e ; set +u
  echo "Enable|disable services" ; sleep 3
  for svc in ${labservices_enabled} ; do
    ln -s /etc/sv/${svc} /etc/runit/runsvdir/default/ || true ;
    #ln -s /etc/sv/${svc} /var/service/ || true ;
  done
  for svc in ${labservices_disabled} ; do
    rm /etc/runit/runsvdir/default/${svc} || true ;
    #rm /var/service/${svc} || true ;
  done

  set +e
  ## scripts/cleanup.sh
  xbps-remove -oOy
}

run_all() {
  install_pkgs
  config_sys
  toggle_svcs
}

#----------------------------------------
${@:-run_all}
