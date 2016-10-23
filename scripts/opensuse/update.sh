#!/bin/sh -eux

MIRROR=${MIRROR:-mirror.math.princeton.edu/pub/opensuse-full/opensuse}

VERSION_ID=$(sed -n 's|VERSION_ID="*\(.*\)"*|\1|p' /etc/os-release)


fix_repos() {
	packman_repo='http://ftp.gwdg.de/pub/linux/misc/packman/suse'

	#distro_version="tumbleweed" ;
	#zypper ar --disable ${packman_repo}/openSUSE_Tumbleweed/ packman ;

	if [[ "$VERSION_ID" =~ "13" ]] ; then
		distro_version="${VERSION_ID}" ;
		zypper ar --disable ${packman_repo}/${VERSION_ID}/ packman ;
	else
		distro_version="leap/${VERSION_ID}" ;
		zypper ar --disable ${packman_repo}/openSUSE_Leap_${VERSION_ID}/ packman ;
	fi

	# naming similar to: repo-oss OR openSUSE-Leap-${VERSION_ID}-Oss
	if [[ "$distro_version" =~ "tumbleweed" ]] ; then
		zypper ar http://${MIRROR}/${distro_version}/repo/oss/ repo-oss ;
		zypper ar http://download.opensuse.org/${distro_version}/repo/non-oss/ repo-non-oss ;
	else
		zypper ar http://${MIRROR}/distribution/${distro_version}/repo/oss/ repo-oss ;
		zypper ar http://${MIRROR}/distribution/${distro_version}/repo/non-oss/ repo-non-oss ;
		zypper ar http://${MIRROR}/update/${distro_version}/oss/ repo-update ;
		zypper ar http://${MIRROR}/update/${distro_version}/non-oss/ repo-update-non-oss ;
	fi
}


set +e ; set +u

. /root/distro_pkgs.txt
if [ -z "$(grep '^export JAVA_HOME' /etc/bash.bashrc)" ] ; then
  echo "export JAVA_HOME=${default_java_home}" >> /etc/bash.bashrc ; 
fi
mkdir -p ${default_java_home}
if [ -z "$(grep '^JAVA_VERSION' ${default_java_home}/release)" ] ; then
  echo JAVA_VERSION="${default_java_version}" >> ${default_java_home}/release ; 
fi

## opensuse/remove-dvd-source.sh
zypper removerepo "openSUSE-${VERSION_ID}-0"


## opensuse/update.sh
zypper repos ; sleep 5
zypper --non-interactive refresh ; zypper --non-interactive update
zypper --non-interactive install --no-recommends sudo
zypper --non-interactive clean
