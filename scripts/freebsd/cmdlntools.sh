#!/bin/sh -eux

export SHAREDNODE=${1:-localhost.local} ; export PRINTNAME=${2:-printer1}
set +e

snapshot_name=pre_cmdlntools-$(date -u "+%Y%m%d") \
  sh $(dirname ${0})/upgradepkgs.sh snapshot

if command -v aria2c > /dev/null ; then
  FETCH_CMD=${FETCH_CMD:-aria2c} ;
fi

pkg update

# Disable X11 because Vagrants VMs are (usually) headless
#sysrc -f /etc/make.conf WITHOUT_X11="YES"

#read -p "Fetch missing distribution components? Enter 'y' to continue [yN]: " response
#if [ "y" = "${response}" ] || [ "Y" = "${response}" ] ; then
#  # fetch missing distribution components like: src.txz
#  # release: [sysctl -n kern.osrelease | freebsd-version] | cut -d- -f1
#  # uname_m: [amd64 | arm64] ; release: X.Y
#  uname_m=$(uname -m) ; release=$(sysctl -n kern.osrelease | cut -d- -f1) ;
#  cd /tmp ;
#  for setX in src ; do
#    fetch ftp://ftp.freebsd.org/pub/FreeBSD/releases/${uname_m}/${release}-RELEASE/${setX}.txz
#    tar -C / -xzvf ${setX}.txz ;
#  done ;
#fi

. /root/scripts/distro_pkgs.ini ; echo ${pkgs_cmdln_tools}

read -p "Enter 'y' to continue [nY]: " response
#if [ "n" = "${response}" ] || [ "N" = "${response}" ] ; then
if [ -n "$(echo ${response} | grep -e '^[Nn].*')" ] ; then
  exit ;
fi
#pkg install [--fetch-only] -Uy pkg0 .. pkgN # ERR, doesn't skip missing
for pkgX in ${pkgs_cmdln_tools} ; do
  pkg install -Uy ${pkgX} ;
done

#uuidgen > /etc/hostid
#/usr/local/bin/dbus-uuidgen --ensure[=/var/lib/dbus/machine-id]
if [ "$(hostname | grep -e 'box.0000')" ] ; then
  idsuffix=$(sysctl -n kern.hostuuid | cut -b33-36) ; # cat /etc/hostid
  for fileX in /etc/hosts /etc/rc.conf /etc/rc.conf.local ; do
    sed -i '' "/box.0000/ s|\(box.\)0000|\1${idsuffix:-0000}|g" ${fileX} ;
  done ;
  hostname $(sysrc -n hostname) ;
fi

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
fi

#                      chmod [g+ws,+t | 3775] /var/mail
chgrp mail /var/mail ; chmod g+ws,+t /var/mail

(cd /usr/share/skel ; mkdir -p dot.gnupg dot.pki dot.ssh)
(cd /root/init/common ; cp -a skel/_gnupg/* /usr/share/skel/dot.gnupg/ ; \
  cp -a skel/_pki/* /usr/share/skel/dot.pki/ ; \
  cp -a skel/_ssh/* /usr/share/skel/dot.ssh/ ; \
  cp -a skel/_gitconfig.sample /usr/share/skel/dot.gitconfig ; \
  cp -a skel/_hgrc.sample /usr/share/skel/dot.hgrc)


set +e ; set +u
if [ ! -f /boot/loader.conf ] ; then touch /boot/loader.conf ; fi
if [ ! -f /etc/rc.conf ] ; then touch /etc/rc.conf ; fi

sysrc devfs_system_ruleset="devfsrules_system"
sysrc syslogd_flags="-ss" ; sysrc ntpd_sync_on_start="YES"
sysrc cron_flags="-J 60 -j 60" #; sysrc anacron_flags+=" -s"
#sysrc mountd_flags="-r"
#sysrc -f /etc/periodic.conf anticongestion_sleeptime="3600"

sysrc -f /etc/periodic.conf daily_clean_tmps_enable="NO"
#sysrc -f /etc/periodic.conf daily_clean_tmps_days="15"
sysrc -f /etc/periodic.conf daily_status_ntpd_enable="YES"
sysrc -f /etc/periodic.conf daily_status_disks_df_flags="-lhT -c"
sysrc -f /etc/periodic.conf daily_output=""
sysrc -f /etc/periodic.conf weekly_output=""
sysrc -f /etc/periodic.conf monthly_output=""
sysrc -f /etc/periodic.conf \
  daily_status_security_output="/var/log/security.out"

if [ ! "$(grep -e '[devfsrules_system=10]' /etc/devfs.rules)" ] ; then
  cat <<-EOF >> /etc/devfs.rules ;
[devfsrules_system=10]
add path 'unlpt*' group cups mode 0660
add path 'ulpt*' group cups mode 0660
add path 'lpt*' group cups mode 0660

#NOTE, find USB device correspond to printer: dmesg | grep -e ugen
#add path 'usb/X.Y.Z' group cups mode 0660
EOF
fi

pw groupadd -n cups -g 193 ; pw groupmod cups -m root
for file1 in lp lpq lpr lprm ; do
  if [ -e /usr/bin/${file1} ] ; then
    mv /usr/bin/${file1} /usr/bin/${file1}.old ;
  fi ;
  if [ 'NetBSD' = "$(uname -s)" ] ; then
    ln -s /usr/pkg/bin/${file1} /usr/bin/${file1} ;
  else
    ln -s /usr/local/bin/${file1} /usr/bin/${file1} ;
  fi
done

sh /root/init/common/cron/bsd/config_cron.sh

smtp_daemon=${smtp_daemon:-sendmail}
sysrc sendmail_enable="YES" ; service sendmail restart
for userX in root packer vagrant ; do
  [ ! -e /var/mail/${userX}.old ] && \
    mv /var/mail/${userX} /var/mail/${userX}.old ;
done

firewall_tool=${firewall_tool:-pf}
sh /root/init/common/firewall/bsd/config_pf.sh #config_pf allow
#diff -s /etc/pf.conf /etc/pf.conf.new ; sleep 5
#(sleep 120 && /sbin/pfctl -d)& && /sbin/pfctl -e
/sbin/pfctl -e

if [ -z "$(grep -e 'domain.*mdns' /etc/pf/outallow_in_allow.rules)" ] ; then
  #echo 'pass in proto udp from any to any port { domain, mdns } keep state' >> /etc/pf/outallow_in_allow.rules ;
  if [ 'FreeBSD' = "$(uname -s)" ] ; then
    sed -i '' 's|domain|domain, mdns|g' /etc/pf/outallow_in_allow.rules ;
  else
    sed -i 's|domain|domain, mdns|g' /etc/pf/outallow_in_allow.rules ;
  fi ;
fi
/sbin/pfctl -s info ; sleep 5 #; /sbin/pfctl -s rules -a '*' ; sleep 5


set -e ; set -u
sh /root/init/common/misc_config.sh cfg_nsswitch_mdns
sh /root/init/common/misc_config.sh cfg_sudo_nopasswd /usr/local/etc/sudoers.d
#sh /root/init/common/misc_config.sh check_clamav
sh /root/init/common/misc_config.sh cfg_sshd /usr/share/skel/dot.ssh
sh /root/init/common/misc_config.sh cfg_shell_keychain /usr/share/skel/dot.cshrc
sh /root/init/common/misc_config.sh cfg_shell_keychain /usr/share/skel/dot.shrc

# As sharedfolders are not in defaults ports tree, we will use NFS sharing
#services_enabled="${services_enabled} rpcbind nfs_server"
sh /root/init/common/misc_config.sh share_nfs_data0 ${SHAREDNODE}

#sh /root/init/common/misc_config.sh cfg_printer_pdf /usr/local/etc/cups \
#  /usr/local/share/cups/model
##sh /root/init/common/misc_config.sh cfg_printer_default ${SHAREDNODE} ${PRINTNAME}
lpstat -t || true ; sleep 5

set +e ; set +u
echo "Enable|disable services" ; sleep 3
for svc in ${services_enabled} ; do
  sysrc ${svc}_enable="YES" ;
done
for svc in ${services_disabled} ; do
  sysrc ${svc}_enable="NO" ;
done


cat << EOF | sendmail -t root
To: packer
Subject: Subject sample

Email sample
EOF
echo Sample email | mail -u vagrant -s "Sample subject" root packer

set -e ; set -u


set +e
## scripts/cleanup.sh
ASSUME_ALWAYS_YES=yes pkg clean -y
if command -v portmaster > /dev/null ; then
  portmaster -a ; portmaster -n --clean-distfiles ;
fi

# Purge files we don't need any longer
rm -rf /var/db/freebsd-update/files
mkdir -p /var/db/freebsd-update/files
rm -f /var/db/freebsd-update/*-rollback
rm -rf /var/db/freebsd-update/install.*
rm -f /*.core ; rm -rf /boot/kernel.old #; rm -rf /usr/src/*
