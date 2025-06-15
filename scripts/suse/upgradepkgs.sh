#!/bin/sh -eux

## scripts/upgradepkgs.sh
set +e ; set +u

snapshot() {
  snapshot_name=${snapshot_name:-snap1-$(date -u "+%Y%m%d")}

  #df_found=$(df -lhT / | sed -n "s|.*\(btrfs\).*$|\1|p ; s|.*\([fuz]fs\).*$|\1|p")
  df_found=$(df -lhT / | grep -e "btrfs" -e "[fuz]fs")
  voltypeX=$(echo ${df_found} | cut -d' ' -f2)

  #if command -v zfs > /dev/null ; then
  #if [ -n "`df -lhT / | grep -e zfs`" ] ; then
  if [ "zfs" = "${voltypeX}" ] ; then
    #ZPOOLNM=${ZPOOLNM:-ospool0} ;
    # ospool0/ROOT/default
    DEV_ROOT=$(mount | grep -e "on / " | cut -d' ' -f1) ;
    ZPOOLNM=$(echo ${DEV_ROOT} | cut -d'/' -f1) ;

    zpool trim ${ZPOOLNM} ; zpool set autotrim=on ${ZPOOLNM} ;
    zfs snapshot ${DEV_ROOT}@${snapshot_name} ;
    # example remove: zfs destroy ospool0/ROOT/default@snap1
    # example restore: zfs rollback ospool0/ROOT/default@snap1

    zfs list -t snapshot ; sleep 5 ;
  #elif command -v btrfs > /dev/null ; then
  #elif [ -n "`df -lhT / | grep -e btrfs`" ] ; then
  elif [ "btrfs" = "${voltypeX}" ] ; then
    fstrim -av ;
    btrfs subvolume snapshot / /.snapshots/${snapshot_name} ;
    # example remove: btrfs subvolume delete /.snapshots/snap1
    # example (manual) restore:
    #   mv /.snapshots/1/snapshot /.snapshots/1/broke-snap1
    #   mv /.snapshots/snap1 /.snapshots/1/snapshot
    #   btrfs subvolume set-default $(btrfs subvolume list / \
    #     | grep "@/.snapshots/1/snapshot" | grep -oP '(?<=ID )[0-9]+') /

    btrfs subvolume list -s / || btrfs subvolume list / ; sleep 5 ;
  #else
  #  #lsblk_found=$(lsblk | grep -e "/[ ]*$" | sed -n "s|.*\(lvm\).*$|\1|p")
  #  lsblk_found=$(lsblk -nlpo name,type,mountpoint | grep -e "/[ ]*$" || true) ;
  #  voltypeX=${voltypeX:-$(echo ${lsblk_found} | cut -d' ' -f2)} ;
  #
  #  fstrim -av ;
  #  #if command -v lvm > /dev/null ; then
  #  #if [ -n "`lsblk | grep -e '/[ ]*$' | grep -e lvm`" ] ; then
  #  if [ "lvm" = "${voltypeX}" ] ; then
  #    #GRP_NM=${GRP_NM:-vg0} ; lv_nm=${lv_nm:-osRoot}
  #    # /dev/mapper/vg0-osRoot
  #    DEV_ROOT=$(mount | grep -e "on / " | cut -d' ' -f1) ;
  #    grp_lv=$(echo ${DEV_ROOT} | cut -d'/' -f4 | tr '-' '/') ;
  #
  #    lvcreate --snapshot --size 2G --name ${snapshot_name} ${grp_lv} ;
  #    # example remove: lvremove vg0/snap1
  #
  #    lvs -S 'lv_attr =~ ^s' || lvs ; sleep 5 ;
  #  fi ;
  fi
  sync
}

fix_repos() {
  MIRROR=${MIRROR:-mirror.math.princeton.edu/pub/opensuse-full/opensuse}
  packman_repo='http://ftp.gwdg.de/pub/linux/misc/packman/suse'

  #distro_version="tumbleweed" ;
  #zypper ar --disable ${packman_repo}/openSUSE_Tumbleweed/ packman ;

  if [[ "${VERSION_ID}" =~ "13" ]] ; then
    distro_version="${VERSION_ID}" ;
    zypper ar --disable ${packman_repo}/${VERSION_ID}/ packman ;
  else
    distro_version="leap/${VERSION_ID}" ;
    zypper ar --disable ${packman_repo}/openSUSE_Leap_${VERSION_ID}/ packman ;
  fi

  # naming similar to: repo-oss OR openSUSE-Leap-${VERSION_ID}-Oss
  if [[ "${distro_version}" =~ "tumbleweed" ]] ; then
    zypper ar http://${MIRROR}/${distro_version}/repo/oss/ repo-oss ;
    zypper ar http://download.opensuse.org/${distro_version}/repo/non-oss/ repo-non-oss ;
  else
    zypper ar http://${MIRROR}/distribution/${distro_version}/repo/oss/ repo-oss ;
    zypper ar http://${MIRROR}/distribution/${distro_version}/repo/non-oss/ repo-non-oss ;
    zypper ar http://${MIRROR}/update/${distro_version}/oss/ repo-update ;
    zypper ar http://${MIRROR}/update/${distro_version}/non-oss/ repo-update-non-oss ;
  fi
}

run_upgradepkgs() {
  . /etc/os-release
  snapshot_name=${ID}_${VERSION_ID}-$(date -u "+%Y%m%d") snapshot

  ## scripts/remove-dvd-source.sh
  zypper removerepo "openSUSE-${VERSION_ID}-0"

  zypper --non-interactive refresh

  zypper --no-refresh repos -u ; sleep 5
  #zypper --no-refresh --dry-run --non-interactive update
  zypper --no-refresh --non-interactive list-updates --all

  read -p "Enter 'y' to continue [yN]: " response
  #if [ ! "y" = "${response}" ] && [ ! "Y" = "${response}" ] ; then
  if [ -z "$(echo ${response} | grep -e '^[Yy].*')" ] ; then
    exit ;
  fi
  #zypper --no-refresh --download-only --non-interactive update
  zypper --no-refresh --non-interactive update

  #zypper --no-refresh --ignore-unknown [--download-only] --non-interactive install pkg0 .. pkgN # OK, skips missing
  zypper --no-refresh --ignore-unknown --non-interactive install pkgUnknown nano pkgMissing zip
  #for pkgX in pkgUnknown nano pkgMissing zip ; do
  #  zypper --no-refresh --non-interactive install ${pkgX} ;
  #done
  zypper locks ; sleep 3

  zypper --no-refresh --non-interactive clean --all


  zypper --no-refresh --non-interactive dist-upgrade

  # Re-set setuid for qemu-bridge-helper
  qemubridge_helper=`find /usr -type f -name qemu-bridge-helper | head -n1`
  if [ -n "${qemubridge_helper}" ] ; then
    #chmod [u+s | 4755] ${qemubridge_helper} ;
    chmod u+s ${qemubridge_helper} ;
  fi
}

#----------------------------------------
${@:-run_upgradepkgs}
