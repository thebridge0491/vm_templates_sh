#!/bin/sh -eux

export SHAREDNODE=${1:-localhost.local} ; export PRINTNAME=${2:-printer1}
set +e

snapshot_name=pre_cmdlntools-$(date -u "+%Y%m%d") \
  sh $(dirname ${0})/upgradepkgs.sh snapshot

apk update ; apk fix

. /root/scripts/distro_pkgs.ini ; echo ${pkgs_cmdln_tools}

read -p "Enter 'y' to continue [nY]: " response
#if [ "n" = "${response}" ] || [ "N" = "${response}" ] ; then
if [ -n "$(echo ${response} | grep -e '^[Nn].*')" ] ; then
  exit ;
fi
#apk [fetch | add] pkg0 .. pkgN # ERR, doesn't skip missing
for pkgX in ${pkgs_cmdln_tools} ; do
  apk add ${pkgX} ;
done

#service dbus start
#dbus-uuidgen --ensure[=/etc/machine-id]
if [ ! -z "$(grep 0000 /etc/hostname)" ] ; then
  idsuffix=$(cat /etc/machine-id | cut -b29-32) ;
  #idsuffix=$(cat /var/lib/dbus/machine-id | cut -b29-32) ;
  for fileX in /etc/hosts /etc/hostname ; do
    sed -i "/box.0000/ s|\(box.\)0000|\1${idsuffix:-0000}|g" ${fileX} ;
  done ;
  hostname -F /etc/hostname || hostname $(cat /etc/hostname) ;
fi

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
fi

#                      chmod [g+ws,+t | 3775] /var/mail
chgrp mail /var/mail ; chmod g+ws,+t /var/mail

(cd /etc/skel ; mkdir -p .gnupg .ssh .pki)
(cd /root/init/common ; cp -a skel/_gnupg/* /etc/skel/.gnupg/ ; \
  cp -a skel/_ssh/* /etc/skel/.ssh/ ; cp -a skel/_pki/* /etc/skel/.pki/ ; \
  cp -a skel/_gitconfig.sample /etc/skel/.gitconfig ; \
  cp -a skel/_hgrc.sample /etc/skel/.hgrc)


set +e ; set +u
#usermod -G plugdev packer
adduser packer plugdev

#mkdir -p /var/lib/clamav ; chown -R clamav:clamav /var/lib/clamav
#touch /var/lib/clamav/clamd.sock

# Only add the secure path line if it is not already present
#grep -q 'secure_path' /etc/sudoers \
#  || sed -i '/Defaults\s\+env_reset/a Defaults\tsecure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"' /etc/sudoers

if [ -n "$(lspci | grep -ie wireless)" ] ; then
  psk=`wpa_passphrase ${SSID:-HOME24-WIFI} ${passphrase:-abcd0123} | sed -n 's|^[[:space:]]*psk=\(.*\)|\1|p'`
  nmcli device wifi list ; sleep 3
  nmcli device wifi connect ${SSID:-HOME24-WIFI} password ${psk}
  #nmcli device connection up ${SSID:-HOME24-WIFI}
  # see /etc/NetworkManager/system-connections/*
fi

sh /root/init/common/cron/linux/config_cron.sh

smtp_daemon=${smtp_daemon:-smtpd}
# smtpd.conf location varies:
#  /etc/mail/smtpd.conf: OpenBSD, Alpine Linux
#  /etc/smtpd/smtpd.conf: Void Linux, Arch Linux
#  /etc/smtpd.conf: Debian
found_smtpdconf=$(find /etc -name smtpd.conf | head -n1)
found_smtpdconf=${found_smtpdconf:-/etc/mail/smtpd.conf}
# config [open]smtpd -- maildir format vice mbox
rc-update add ${smtp_daemon} default || true ; rc-service ${smtp_daemon} restart || true
sh /root/init/common/smtp/linux/config_opensmtpd.sh
if [ -n "$(grep 'local ! rcpt-to' ${found_smtpdconf})" ] ; then
  for userX in packer vagrant ; do
    [ ! -e /var/mail/${userX}.old ] && \
      mv /var/mail/${userX} /var/mail/${userX}.old ;
  done ;
  if [ ! "Linux" = "$(uname -s)" ] ; then
    mkdir -p /var/mail/packer ; chown packer:wheel /var/mail/packer ;
  else
    mkdir -p /var/mail/packer/{cur,new,tmp} ;
    chown -R packer:mail /var/mail/packer ;
  fi ;
fi

firewall_tool=${firewall_tool:-firewalld}
#sh /root/init/common/firewall/linux/config_nftables.sh #config_nftables allow
##diff -s /etc/nftables.conf /etc/nftables.conf.new
##(sleep 120 && nft flush ruleset)& && nft -f /etc/nftables.conf
#nft -f /etc/nftables.conf
sh /root/init/common/firewall/linux/config_firewalld.sh #cmds_firewalld allow
#(sleep 120 && firewall-offline-cmd --disabled)& && \
#  (firewall-offline-cmd --enabled ; firewall-cmd --reload)
firewall-offline-cmd --enabled ; firewall-cmd --reload

#if [ -z "$(grep -e 'domain.*mdns' /etc/nftables.conf /etc/nftables/out*_nftables.conf)" ] ; then
#  #nft add rule inet filter in_allow udp port { domain, mdns } accept ;
#  sed -i 's|domain|domain, mdns|g' /etc/nftables.conf \
#    /etc/nftables/out*_nftables.conf ;
#fi
#nft list tables ; sleep 5 ; nft list ruleset ; sleep 5
if [ $(firewall-cmd --zone=public --query-service=mdns) ] ; then
  #yast firewall services add zone=EXT service=service:avahi ; # openSUSE
  firewall-cmd --permanent --zone=public --add-service=mdns ;
fi
firewall-cmd --get-active-zones ; sleep 5
#ipset list ; sleep 5
firewall-cmd --state ; sleep 5 ; firewall-cmd --zone=public --list-all ; sleep 5


set -e ; set -u
sh /root/init/common/misc_config.sh cfg_nsswitch_mdns
sh /root/init/common/misc_config.sh cfg_sudo_nopasswd /etc/sudoers.d
sh /root/init/common/misc_config.sh cfg_inputrc_histsearch
#sh /root/init/common/misc_config.sh check_clamav
sh /root/init/common/misc_config.sh cfg_sshd
sh /root/init/common/misc_config.sh cfg_shell_keychain
sh /root/init/common/misc_config.sh share_nfs_data0 ${SHAREDNODE}
#sh /root/init/common/misc_config.sh cfg_printer_pdf
##sh /root/init/common/misc_config.sh cfg_printer_default ${SHAREDNODE} ${PRINTNAME}
lpstat -t || true ; sleep 5

set +e ; set +u
echo "Enable|disable services" ; sleep 3
boot_svcs="networking urandom hostname hwclock modules sysctl bootmisc swap loadkmap syslog rsyslog lvm btrfs-scan"
shutdown_svcs="mount-ro killprocs savecache"
sysinit_svcs="devfs dmesg mdev hwdrivers udev udev-trigger udev-settle zfs-import zfs-mount"
for svc in ${services_enabled} ; do
  if [ "$(echo ${boot_svcs} | grep ${svc})" ] ; then
    rc-update add ${svc} boot || true ;
  elif [ "$(echo ${shutdown_svcs} | grep ${svc})" ] ; then
    rc-update add ${svc} shutdown || true ;
  elif [ "$(echo ${sysinit_svcs} | grep ${svc})" ] ; then
    rc-update add ${svc} sysinit || true ;
  else
    rc-update add ${svc} default || true ;
  fi ;
done
for svc in ${services_disabled} ; do
  if [ "$(echo ${boot_svcs} | grep ${svc})" ] ; then
    rc-update del ${svc} boot || true ;
  elif [ "$(echo ${shutdown_svcs} | grep ${svc})" ] ; then
    rc-update del ${svc} shutdown || true ;
  elif [ "$(echo ${sysinit_svcs} | grep ${svc})" ] ; then
    rc-update del ${svc} sysinit || true ;
  else
    rc-update del ${svc} default || true ;
  fi ;
done


cat << EOF | sendmail -t root
To: packer
Subject: Subject sample

Email sample
EOF
mail_cmd=$(basename $(which nail s-nail mailx | head -n1))
echo Sample email | ${mail_cmd:-mail} -r vagrant@$(hostname -s || hostname) \
  -s "Sample subject" root packer
set -e ; set -u


set +e
## scripts/cleanup.sh
apk -v cache clean
