#!/bin/sh -eux

LANGS=${@:-py c java} ; export LANGS
set +e

snapshot_name=pre_codelab-$(date -u "+%Y%m%d") \
  sh $(dirname ${0})/upgradepkgs.sh snapshot

if command -v aria2c > /dev/null ; then
  FETCH_CMD=${FETCH_CMD:-aria2c} ;
fi

pkg update
#pkg upgrade --fetch-only -Uy ; pkg upgrade -Uy
. /root/scripts/distro_pkgs.ini
for langX in ${LANGS} ; do
  echo ${pkgs_lang_${langX}} ;
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
  esac
  #pkg install [--fetch-only] -Uy pkg0 .. pkgN # ERR, doesn't skip missing
  for pkgX in ${pkgs_var} ; do
    pkg install -Uy ${pkgX} ;
  done ;
done

if [ -n "$(java -version)" ] ; then
  #java_home=$(dirname $(dirname $(realpath $(which java)))) ;
  java_home=$(realpath $(which java) | sed "s:/bin/java::") ;
  #if [ -z "$(grep '^setenv JAVA_HOME' /etc/csh.cshrc)" ] ; then
  #  echo 'setenv JAVA_HOME ${java_home}' >> /etc/csh.cshrc ;
  if [ -z "$(grep '^export JAVA_HOME' /etc/profile.d/jdk.sh)" ] ; then
    echo 'export JAVA_HOME=${java_home}' >> /etc/profile.d/jdk.sh ;
  fi ;
  if [ -z "$(grep '^fdesc' /etc/fstab)" ] ; then
    echo 'fdesc  /dev/fd  fdescfs  rw  0  0' >> /etc/fstab ;
  fi ;
  # PATH_TO_FX location varies: # try find javafx[-.]fxml*.jar
  #  [/usr/lib/jvm/java-[N]-openjfx|/opt/javafx-sdk-[N]]/lib: Arch Linux, Gluon download
  #  /usr/local/openjfx[N]/lib: FreeBSD
  #  /usr/share/openjfx: Debian
  found_jfxjar=$(find /usr /opt -name "javafx[-.]fxml*.jar" | head -n1) ;
  found_jfxjar=${found_jfxjar:-/usr/lib/jvm/java-11-openjfx/lib/javafx.fxml.jar} ;
  #if [ -z "$(grep '^setenv PATH_TO_FX' /etc/csh.cshrc)" ] ; then
  #  echo "setenv PATH_TO_FX $(dirname ${found_jfxjar})" >> /etc/csh.cshrc ;
  if [ -z "$(grep '^export PATH_TO_FX' /etc/profile.d/jdk.sh)" ] ; then
    echo "export PATH_TO_FX=$(dirname ${found_jfxjar})" >> /etc/profile.d/jdk.sh ;
  fi ;
fi


echo "Fix .NET access problem SSL CA cert path" >> /dev/stderr ; sleep 3
mkdir -p /compat/linux/etc/pki/tls/certs
ln -s /usr/local/share/certs/ca-root-nss.crt \
  /compat/linux/etc/pki/tls/certs/ca-bundle.crt


set +e ; set +u
echo "Enable|disable services" ; sleep 3
for svc in ${labservices_enabled} ; do
  sysrc ${svc}_enable="YES" ;
done
for svc in ${labservices_disabled} ; do
  sysrc ${svc}_enable="NO" ;
done

set +e
## scripts/cleanup.sh
ASSUME_ALWAYS_YES=yes pkg clean -y
if command -v portmaster > /dev/null ; then
  portmaster -a ; portmaster -n --clean-distfiles ;
fi
