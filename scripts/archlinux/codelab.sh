#!/bin/sh -eux

LANGS=${@:-py c java} ; export LANGS

set +e
if command -v systemctl > /dev/null ; then
  systemctl stop pamac.service ;
elif command -v rc-update > /dev/null ; then
  rc-service pamac stop ;
elif command -v sv > /dev/null ; then
  sv down pamac ;
elif command -v s6-rc > /dev/null ; then
  s6-rc -d change pamac ;
fi
rm /var/lib/pacman/db.lck
#set -e

pacman --noconfirm -Syy ; pacman --noconfirm -Syu
. /root/init/archlinux/distro_pkgs.ini
for langX in ${LANGS} ; do
  case ${langX} in
    py) pkgs_var=${pkgs_lang_py} ;;
    c) pkgs_var=${pkgs_lang_c} ;;
    java) rm -r ${default_java_home} ; pkgs_var=${pkgs_lang_java} ;;
    scm) pkgs_var=${pkgs_lang_scm} ;;
    hs) pkgs_var=${pkgs_lang_hs} ;;
    scala) rm -r ${default_java_home} ; pkgs_var=${pkgs_lang_scala} ;;
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
  esac
  for pkgX in ${pkgs_var} ; do
	pacman --noconfirm --needed -S ${pkgX} ;
  done ;
done

if [ -z "$(grep '^export JAVA_HOME' /etc/bash.bashrc)" ] ; then
  echo "export JAVA_HOME=${default_java_home}" >> /etc/bash.bashrc ;
fi
mkdir -p ${default_java_home}
if [ -z "$(grep '^JAVA_VERSION' ${default_java_home}/release)" ] ; then
  echo JAVA_VERSION="${default_java_version}" >> ${default_java_home}/release ;
fi

echo "Install xterm,Xauth pkgs for X11 forwarding over SSH" >> /dev/stderr ; sleep 3
for pkgX in xorg-xauth xorg-xhost xterm ; do
  pacman --noconfirm --needed -S $pkgX ;
done

set -e

## scripts/cleanup.sh
pacman --noconfirm -Sc
