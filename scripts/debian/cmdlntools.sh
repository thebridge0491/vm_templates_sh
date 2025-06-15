#!/bin/sh -eux

export SHAREDNODE=${1:-localhost.local} ; export PRINTNAME=${2:-printer1}
set +e

snapshot_name=pre_cmdlntools-$(date -u "+%Y%m%d") \
  sh $(dirname ${0})/upgradepkgs.sh snapshot

apt-config dump | grep -we Recommends -e Suggests | sed 's|1|0|' | \
  tee /etc/apt/apt.conf.d/999norecommends
# apt-get -o Acquire::ForceIPv4=true ...
echo '#Acquire::ForceIPv4 "true";' > /etc/apt/apt.conf.d/99force-ipv4

apt-get --allow-releaseinfo-change -y update

. /root/scripts/distro_pkgs.ini ; echo ${pkgs_cmdln_tools}

read -p "Enter 'y' to continue [nY]: " response
#if [ "n" = "${response}" ] || [ "N" = "${response}" ] ; then
if [ -n "$(echo ${response} | grep -e '^[Nn].*')" ] ; then
  exit ;
fi
#apt-get [--download-only] -y install pkg0 .. pkgN # ERR, doesn't skip missing
for pkgX in ${pkgs_cmdln_tools} ; do
  apt-get -y install ${pkgX} ;
done
tasksel --new-install --list-tasks ; sleep 5

#dbus-uuidgen --ensure[=/etc/machine-id]
if [ "$(hostname | grep -e 'box.0000')" ] ; then
  idsuffix=$(cat /var/lib/dbus/machine-id | cut -b29-32) ; # cat /etc/machine-id
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
#update-alternatives --get-selections
#update-alternatives --config [java | javac | jar | javadoc | javap | jdb | keytool]
# or
#update-java-alternatives --list
#update-java-alternatives --set java-[11]-openjdk-[amd64]

#                      chmod [g+ws,+t | 3775] /var/mail
chgrp mail /var/mail ; chmod g+ws,+t /var/mail

(cd /etc/skel ; mkdir -p .gnupg .pki .ssh)
(cd /root/init/common ; cp -a skel/_gnupg/* /etc/skel/.gnupg/ ; \
  cp -a skel/_ssh/* /etc/skel/.ssh/ ; cp -a skel/_pki/* /etc/skel/.pki/ ; \
  cp -a skel/_gitconfig.sample /etc/skel/.gitconfig ; \
  cp -a skel/_hgrc.sample /etc/skel/.hgrc)


set +e ; set +u
cp -n /root/init/common/smtp/linux/mail.rc.sample /etc/mail.rc

##cp /usr/share/doc/nftables/examples/sysvinit/nftables.init /etc/init.d/nftables
##chmod +x /etc/init.d/nftables
##if command -v update-rc.d > /dev/null ; then
##  cat > /etc/network/if-pre-up.d/nftables << EOF ;
###!/bin/sh
##/usr/bin/env nft -f /etc/nftables.conf
##
##EOF
##  chmod +x /etc/network/if-pre-up.d/nftables ;
##fi

#mkdir -p /var/lib/clamav ; chown -R clamav:clamav /var/lib/clamav
#touch /var/lib/clamav/clamd.sock

# Only add the secure path line if it is not already present
grep -q 'secure_path' /etc/sudoers \
  || sed -i '/Defaults\s\+env_reset/a Defaults\tsecure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"' /etc/sudoers

if [ -n "$(lspci | grep -ie wireless)" ] ; then
  psk=`wpa_passphrase ${SSID:-HOME24-WIFI} ${passphrase:-abcd0123} | sed -n 's|^[[:space:]]*psk=\(.*\)|\1|p'`
  nmcli device wifi list ; sleep 3
  nmcli device wifi connect ${SSID:-HOME24-WIFI} password ${psk}
  #nmcli device connection up ${SSID:-HOME24-WIFI}
  # see /etc/NetworkManager/system-connections/*
fi

sh /root/init/common/cron/linux/config_cron.sh

smtp_daemon=${smtp_daemon:-opensmtpd}
# smtpd.conf location varies:
#  /etc/mail/smtpd.conf: OpenBSD, Alpine Linux
#  /etc/smtpd/smtpd.conf: Void Linux, Arch Linux
#  /etc/smtpd.conf: Debian
found_smtpdconf=$(find /etc -name smtpd.conf | head -n1)
found_smtpdconf=${found_smtpdconf:-/etc/mail/smtpd.conf}
# config [open]smtpd -- maildir format vice mbox
if command -v systemctl > /dev/null ; then
  systemctl enable ${smtp_daemon} || true ; systemctl restart ${smtp_daemon} || true ;
elif command -v sv > /dev/null ; then
  ln -s /etc/sv/${smtp_daemon} /etc/service/ || true ; sv restart ${smtp_daemon} || true ;
elif command -v rc-update > /dev/null ; then
  rc-update add ${smtp_daemon} default || true ; rc-service ${smtp_daemon} restart || true ;
elif command -v update-rc.d > /dev/null ; then
  update-rc.d ${smtp_daemon} defaults || true ; invoke-rc.d ${smtp_daemon} restart || true ;
fi
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
##sh /root/init/common/firewall/linux/config_ufw.sh cmds_ufw allow
##(sleep 120 && ufw disable)& && ufw enable
#ufw enable
#sh /root/init/common/firewall/linux/config_nftables.sh #config_nftables allow
##diff -s /etc/nftables.conf /etc/nftables.conf.new
##(sleep 120 && nft flush ruleset)& && nft -f /etc/nftables.conf
#nft -f /etc/nftables.conf
sh /root/init/common/firewall/linux/config_firewalld.sh #cmds_firewalld allow
#(sleep 120 && firewall-offline-cmd --disabled)& && \
#  (firewall-offline-cmd --enabled ; firewall-cmd --reload)
firewall-offline-cmd --enabled ; firewall-cmd --reload

##ufw allow in svc MDNS
##ufw status ; sleep 5 ; ufw show user-rules ; sleep 5
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
#sh /root/init/common/misc_config.sh cfg_printer_pdf /etc/cups \
#  /usr/share/ppd/cups-pdf
##sh /root/init/common/misc_config.sh cfg_printer_default ${SHAREDNODE} ${PRINTNAME}
lpstat -t || true ; sleep 5

set +e ; set +u
# service(s) enabled by package install trigger: dbus, mdns (avahi), firewalld, network-manager
echo "Enable|disable services" ; sleep 3
for svc in ${services_enabled} ; do
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
for svc in ${services_disabled} ; do
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
apt-get -y clean
