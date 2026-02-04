#!/bin/sh -eux

## scripts/upgradepkgs.sh
set +e

fetch_distrosets() {
  # src ports
  distrosets=${distrosets:-src}

  if command -v aria2c > /dev/null ; then
    FETCH_CMD=${FETCH_CMD:-aria2c} ;
  fi

  read -p "Extract after fetch distribution components/sets? Enter 'y' to continue [yN]: " response
  # fetch distribution components like: src.txz
  # release: [sysctl -n kern.osrelease | freebsd-version] | cut -d- -f1
  # uname_m: [amd64 | arm64] ; release: X.Y
  uname_m=$(uname -m) ; release=$(sysctl -n kern.osrelease | cut -d- -f1)
  cd /tmp
  for setX in ${distrosets} ; do
    fetch ftp://ftp.freebsd.org/pub/FreeBSD/releases/${uname_m}/${release}-RELEASE/${setX}.txz
    if [ "y" = "${response}" ] || [ "Y" = "${response}" ] ; then
      tar -C / -xzvf ${setX}.txz ;
    fi ;
  done
}

snapshot() {
  snapshot_name=${snapshot_name:-snap1-$(date -u "+%Y%m%d")}

  #df_found=$(df -lhT / | sed -n "s|.*\(btrfs\).*$|\1|p ; s|.*\([fuz]fs\).*$|\1|p")
  df_found=$(df -lhT / | grep -e "btrfs" -e "[fuz]fs")
  voltypeX=$(echo ${df_found} | cut -d' ' -f2)

  #if command -v zfs > /dev/null ; then
  #if [ -n "`df -lhT / | grep -e zfs`" ] ; then
  if [ "zfs" = "${voltypeX}" ] ; then
    #ZPOOLNM=${ZPOOLNM:-fspool0} ;
    # fspool0/ROOT/default
    DEV_ROOT=$(mount | grep -e "on / " | cut -d' ' -f1) ;
    ZPOOLNM=$(echo ${DEV_ROOT} | cut -d'/' -f1) ;

    zpool trim ${ZPOOLNM} ; zpool set autotrim=on ${ZPOOLNM} ;
    zfs snapshot ${DEV_ROOT}@${snapshot_name} ;
    # example remove: zfs destroy fspool0/ROOT/default@snap1
    # example restore: zfs rollback fspool0/ROOT/default@snap1

    zfs list -t snapshot ; sleep 5 ;
  ##else
  ##elif [ -n "`df -lhT / | grep -e ufs`" ] ; then
  #elif [ "ufs" = "${voltypeX}" ] ; then
  #  GRP_NM=${GRP_NM:-fbsd0} ;
  #
  #  #mount -u -o snapshot /.snap/${snapshot_name} / ;
  #  mksnap_ffs / /.snap/${snapshot_name} ;
  #  # example remove: rm /.snap/snap1
  #
  #  find / -flags snapshot ; snapinfo / ; sleep 5 ;
  #  fsck_ffs -E -Z /dev/gpt/${GRP_NM}-fsRoot ;
  #  fsck_ffs -E -Z /dev/gpt/${GRP_NM}-fsVar ;
  fi
  sync
}

run_upgradepkgs() {
  . /etc/os-release
  #snapshot_name=$(uname -s)_$(uname -r | cut -d- -f1)-$(date -u "+%Y%m%d") \
  #  snapshot
  snapshot_name=${ID}_${VERSION_ID}-$(date -u "+%Y%m%d") snapshot

  if command -v aria2c > /dev/null ; then
    FETCH_CMD=${FETCH_CMD:-aria2c} ;
  fi
  env ASSUME_ALWAYS_YES=true pkg bootstrap
  pkg update

  #pkg -vv | grep -A99 -e "Repositories:" ; sleep 5
  pkg -vv | sed -n "/Repositories:/,/^$/p" ; sleep 5
  #pkg version -Ul\<
  pkg upgrade --dry-run -Uy

  read -p "Enter 'y' to continue [yN]: " response
  #if [ ! "y" = "${response}" ] && [ ! "Y" = "${response}" ] ; then
  if [ -z "$(echo ${response} | grep -e '^[Yy].*')" ] ; then
    exit ;
  fi
  #pkg upgrade --fetch-only -Uy # or pkg fetch --available-updates -Udy
  pkg upgrade -Uy

  #pkg install [--fetch-only] -Uy pkg0 .. pkgN # ERR, doesn't skip missing
  for pkgX in pkgUnknown nano pkgMissing zip ; do
    pkg install -Uy ${pkgX} ;
  done
  pkg lock -lq ; sleep 3


  # Unset these as if they're empty it'll break freebsd-update
  [ -z "${no_proxy}" ] && unset no_proxy
  [ -z "${http_proxy}" ] && unset http_proxy
  [ -z "${https_proxy}" ] && unset https_proxy

  major_version="$(uname -r | awk -F. '{print $1}')"

  grep -ie CreateBootEnv /etc/freebsd-update.conf
  bectl list ; bectl list -c creation ; sleep 5

  # Update FreeBSD
  if [ "${major_version}" -lt 10 ] ; then
    # Allow freebsd-update to run fetch without stdin attached to a terminal
    sed 's|\[ ! -t 0 \]|false|' /usr/sbin/freebsd-update > /tmp/freebsd-update ;
    chmod +x /tmp/freebsd-update ;

    freebsd_update="/tmp/freebsd-update" ;
  else
    sed 's|sleep.*|sleep 30|' /usr/sbin/freebsd-update > /tmp/freebsd-update ;
    chmod +x /tmp/freebsd-update ;
    #freebsd_update="/usr/sbin/freebsd-update --not-running-from-cron" ;
    freebsd_update="/tmp/freebsd-update --not-running-from-cron" ;
  fi

  # NOTE: the install action fails if there are no updates so || true it
  env PAGER=cat ${freebsd_update} cron      # interactive: fetch, else cron
  env PAGER=cat ${freebsd_update} install || true

  ASSUME_ALWAYS_YES=yes pkg clean -y
  if command -v portmaster > /dev/null ; then
    portmaster -a ; portmaster -n --clean-distfiles ; sleep 3
  fi
}

#----------------------------------------
${@:-run_upgradepkgs}
