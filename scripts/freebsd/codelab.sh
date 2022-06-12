#!/bin/sh -eux

if command -v aria2c > /dev/null ; then
	FETCH_CMD=${FETCH_CMD:-aria2c} ;
fi

export SED_INPLACE="sed -i ''"
LANGS=${@:-py c java} ; export LANGS

set +e

. /root/init/freebsd/distro_pkgs.ini
pkg update
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
  esac
  for pkgX in ${pkgs_var} ; do
	pkg install -Uy ${pkgX} ;
  done ;
done

if [ -z "$(grep '^setenv JAVA_HOME' /etc/csh.cshrc)" ] ; then
  echo "setenv JAVA_HOME ${default_java_home}" >> /etc/csh.cshrc ;
fi
if [ -z "$(grep '^fdesc' /etc/fstab)" ] ; then
  echo 'fdesc  /dev/fd  fdescfs  rw  0  0' >> /etc/fstab ;
fi
if [ -z "$(grep '^setenv JAVAFX_HOME' /etc/csh.cshrc)" ] ; then
  echo "setenv JAVAFX_HOME ${default_javafx_home}" >> /etc/csh.cshrc ;
fi


echo "Install xterm,Xauth pkgs for X11 forwarding over SSH" >> /dev/stderr ; sleep 3
for pkgX in xauth xterm ; do
  pkg install -Uy $pkgX ;
done

echo "Fix .NET access problem SSL CA cert path" >> /dev/stderr ; sleep 3
mkdir -p /compat/linux/etc/pki/tls/certs
ln -s /usr/local/share/certs/ca-root-nss.crt \
  /compat/linux/etc/pki/tls/certs/ca-bundle.crt

set +e
## scripts/cleanup.sh
pkg clean -y
portmaster -n --clean-distfiles

# Purge files we don't need any longer
rm -rf /var/db/freebsd-update/files
mkdir -p /var/db/freebsd-update/files
rm -f /var/db/freebsd-update/*-rollback
rm -rf /var/db/freebsd-update/install.*
rm -f /*.core ; rm -rf /boot/kernel.old #; rm -rf /usr/src/*
