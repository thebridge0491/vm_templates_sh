#!/bin/sh -eux

export SED_INPLACE="sed -i"
LANGS=${@:-py c java} ; export LANGS

set +e

. /root/init/debian/distro_pkgs.ini
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
    *) pkgs_var=${pkgs_lang_py} ;;
  esac
  for pkgX in ${pkgs_var} ; do
	apt-get -y --no-install-recommends install ${pkgX} ;
  done ;
done

if [ -z "$(grep '^export JAVA_HOME' /etc/bash.bashrc)" ] ; then
  echo "export JAVA_HOME=${default_java_home}" >> /etc/bash.bashrc ;
fi
mkdir -p ${default_java_home}
if [ -z "$(grep '^JAVA_VERSION' ${default_java_home}/release)" ] ; then
  echo JAVA_VERSION="${default_java_version}" >> ${default_java_home}/release ;
fi
if [ -z "$(grep '^export JAVAFX_HOME' /etc/bash.bashrc)" ] ; then
  echo "export JAVAFX_HOME=${default_javafx_home}" >> /etc/bash.bashrc ;
fi
#update-alternatives --get-selections
#update-alternatives --config [java | javac | jar | javadoc | javap | jdb | keytool]
# or
#update-java-alternatives --list
#update-java-alternatives --set java-[11]-openjdk-[amd64]

echo "Install xterm,Xauth pkgs for X11 forwarding over SSH" >> /dev/stderr ; sleep 3
for pkgX in xauth xterm ; do
  apt-get -y --no-install-recommends install $pkgX ;
done

set -e ; set -u

## scripts/cleanup.sh
apt-get -y clean
