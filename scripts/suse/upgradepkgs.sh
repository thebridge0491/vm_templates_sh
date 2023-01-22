#!/bin/sh -eux

## scripts/upgradepkgs.sh
MIRROR=${MIRROR:-mirror.math.princeton.edu/pub/opensuse-full/opensuse}
. /etc/os-release


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

## scripts/remove-dvd-source.sh
zypper removerepo "openSUSE-${VERSION_ID}-0"


zypper repos ; sleep 5
zypper --non-interactive refresh ; zypper --non-interactive update
zypper --non-interactive install --no-recommends sudo
zypper locks ; sleep 3

zypper --non-interactive clean
if command -v zpool > /dev/null ; then
  ZPOOLNM=${ZPOOLNM:-ospool0} ;
  zpool trim ${ZPOOLNM} ; zpool set autotrim=on ${ZPOOLNM} ;

  zfs list -t snapshot ; sleep 5 ;
else
  fstrim -av ;
  if command -v btrfs > /dev/null ; then
    btrfs subvolume list / ;
  elif command -v lvcreate > /dev/null ; then
    lvs ;
  fi ;
  sleep 5 ;
fi
sync
