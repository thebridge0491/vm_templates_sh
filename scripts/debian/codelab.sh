#!/bin/sh -eux

LANGS=${@:-py c java} ; export LANGS
set +e

snapshot_name=pre_codelab-$(date -u "+%Y%m%d") \
  sh $(dirname ${0})/upgradepkgs.sh snapshot

apt-config dump | grep -we Recommends -e Suggests | sed 's|1|0|' | \
  tee /etc/apt/apt.conf.d/999norecommends
# apt-get -o Acquire::ForceIPv4=true ...
echo '#Acquire::ForceIPv4 "true";' > /etc/apt/apt.conf.d/99force-ipv4

apt-get --allow-releaseinfo-change -y update
#apt-get --download-only -y upgrade ; apt-get -y upgrade
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
  #apt-get [--download-only] -y install pkg0 .. pkgN # ERR, doesn't skip missing
  for pkgX in ${pkgs_var} ; do
    apt-get --no-install-recommends -y install ${pkgX} ;
  done ;
done

if [ -n "$(java -version)" ] ; then
  #java_home=$(dirname $(dirname $(realpath $(which java)))) ;
  java_home=$(realpath $(which java) | sed "s:/bin/java::") ;
  #if [ -z "$(grep '^export JAVA_HOME' /etc/bash.bashrc)" ] ; then
  if [ -z "$(grep '^export JAVA_HOME' /etc/profile.d/jdk.sh)" ] ; then
    echo 'export JAVA_HOME=${java_home}' >> /etc/profile.d/jdk.sh ;
  fi ;
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
#update-alternatives --get-selections
#update-alternatives --config [java | javac | jar | javadoc | javap | jdb | keytool]
# or
#update-java-alternatives --list
#update-java-alternatives --set java-[11]-openjdk-[amd64]


set +e ; set +u
# service(s) enabled by package install trigger: dbus
echo "Enable|disable services" ; sleep 3
for svc in ${labservices_enabled} ; do
  if command -v systemctl > /dev/null ; then
    systemctl unmask ${svc} || true ; systemctl enable ${svc} || true ;
  elif command -v sv > /dev/null ; then
    ln -s /etc/sv/${svc} /etc/service/ || true ;
  elif command -v rc-update > /dev/null ; then
    rc-update add ${svc} default || true ;
  elif command -v update-rc.d > /dev/null ; then
    update-rc.d ${svc} defaults || true ;
  fi ;
done
for svc in ${labservices_disabled} ; do
  if command -v systemctl > /dev/null ; then
    systemctl disable ${svc} || true ; systemctl mask ${svc} || true ;
  elif command -v sv > /dev/null ; then
    rm /var/service/${svc} || true ;
  elif command -v rc-update > /dev/null ; then
    rc-update del ${svc} default || true ;
  elif command -v update-rc.d > /dev/null ; then
    update-rc.d ${svc} remove || true ;
  fi ;
done


set +e
## scripts/cleanup.sh
apt-get -y clean
