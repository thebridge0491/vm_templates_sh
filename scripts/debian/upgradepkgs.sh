#!/bin/sh -eux

## scripts/upgradepkgs.sh
set +e

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
    #   btrfs subvolume snapshot /.snapshots/snap1 /.snapshots/1/snapshot
    #   #btrfs subvolume set-default /.snapshots/1/snapshot
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

run_upgradepkgs() {
  . /etc/os-release
  snapshot_name=${ID}_${VERSION_ID}-$(date -u "+%Y%m%d")
  if [ -n "${VERSION_CODENAME}" ] ; then
    snapshot_name=${ID}-${VERSION_ID}_${VERSION_CODENAME}-$(date -u "+%Y%m%d") ;
  fi
  snapshot

  #arch="$(uname -r | sed 's|^.*[0-9]\{1,\}\.[0-9]\{1,\}\.[0-9]\{1,\}\(-[0-9]\{1,2\}\)-||')"
  #sed -i '/main.*$/ s|main.*$|main contrib non-free|' /etc/apt/sources.list
  #
  #apt-get -y upgrade linux-image-${arch}
  #apt-get -y install linux-headers-${arch} #linux-headers-$(uname -r)

  apt-get --allow-releaseinfo-change -y update

  tail -vn+1 /etc/apt/sources.list /etc/apt/sources.list.d/*.list \
    | grep -ve "^#" ; sleep 5
  #apt list --upgradeable
  apt-get --simulate -y upgrade

  read -p "Enter 'y' to continue [yN]: " response
  #if [ ! "y" = "${response}" ] && [ ! "Y" = "${response}" ] ; then
  if [ -z "$(echo ${response} | grep -e '^[Yy].*')" ] ; then
    exit ;
  fi
  #apt-get --download-only -y upgrade
  apt-get -y upgrade

  #apt-get [--download-only] -y install pkg0 .. pkgN # ERR, doesn't skip missing
  for pkgX in pkgUnknown nano pkgMissing zip ; do
    apt-get -y install ${pkgX} ;
  done
  #dpkg -l | grep "^hi"
  apt-mark showhold ; sleep 3


  apt-get -y dist-upgrade

  #if [ -d /etc/init ] ; then
  #  # update package index on boot
  #  sh -c 'cat > /etc/init/refresh-apt.conf' << EOF ;
  #description "update package index"
  #start on networking
  #task
  #exec /usr/bin/apt-get update
  #EOF
  #fi

  # Re-set setuid for qemu-bridge-helper
  qemubridge_helper=`find /usr -type f -name qemu-bridge-helper | head -n1`
  if [ -n "${qemubridge_helper}" ] ; then
    #chmod [u+s | 4755] ${qemubridge_helper} ;
    chmod u+s ${qemubridge_helper} ;
  fi

  #apt-get --purge [--dry-run] autoremove # remove old pkgs, kernels
  apt-get -y clean
}

#----------------------------------------
${@:-run_upgradepkgs}
