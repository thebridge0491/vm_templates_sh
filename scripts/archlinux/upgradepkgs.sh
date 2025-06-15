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

run_upgradepkgs() {
  . /etc/os-release
  if [ ! -e /etc/os-release ] && [ -f /usr/lib/os-release ] ; then
    . /usr/lib/os-release ;
  fi
  snapshot_name=${ID}_${VERSION_ID:-rolling}-$(date -u "+%Y%m%d") snapshot

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

  pacman -Syy --noconfirm

  tail -vn+1 /etc/pacman.conf | grep -ve "^#" -ve "^\s*$"
  tail -vn+1 /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist-arch \
    | grep -ve "^#" | head -n10 ; sleep 5
  pacman -Qu

  read -p "Enter 'y' to continue [yN]: " response
  #if [ ! "y" = "${response}" ] && [ ! "Y" = "${response}" ] ; then
  if [ -z "$(echo ${response} | grep -e '^[Yy].*')" ] ; then
    exit ;
  fi
  #pacman -Suw --noconfirm
  pacman -Su --noconfirm

  #pacman --needed -S [-w] --noconfirm pkg0 .. pkgN # OK, skips missing ? 1 error only
  pacman --needed -S --noconfirm pkgUnknown nano pkgMissing zip
  #for pkgX in pkgUnknown nano pkgMissing zip ; do
  #  pacman --noconfirm --needed -S ${pkgX} ;
  #done
  grep -e '^IgnorePkg' /etc/pacman.conf ; sleep 3

  pacman -Sc --noconfirm


  # Re-set setuid for qemu-bridge-helper
  qemubridge_helper=`find /usr -type f -name qemu-bridge-helper | head -n1`
  if [ -n "${qemubridge_helper}" ] ; then
    #chmod [u+s | 4755] ${qemubridge_helper} ;
    chmod u+s ${qemubridge_helper} ;
  fi
}

#----------------------------------------
${@:-run_upgradepkgs}
