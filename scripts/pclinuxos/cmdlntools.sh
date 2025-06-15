#!/bin/sh -eux

export SHAREDNODE=${1:-localhost.local} ; export PRINTNAME=${2:-printer1}
set +e

snapshot_name=pre_cmdlntools-$(date -u "+%Y%m%d") \
  sh $(dirname ${0})/upgradepkgs.sh snapshot

apt-config dump | grep -we Recommends -e Suggests | sed 's|1|0|' | \
  tee /etc/apt/apt.conf.d/999norecommends
# apt-get -o Acquire::ForceIPv4=true ...
echo '#Acquire::ForceIPv4 "true";' > /etc/apt/apt.conf.d/99force-ipv4
# apt-get -o Acquire::Retries=3 ...
echo 'Acquire::Retries "3";' > /etc/apt/apt.conf.d/99retries03

# fix AND re-attempt install for infrequent errors
apt-get -y update ; apt-get --fix-broken -y install

. /root/scripts/distro_pkgs.ini ; echo ${pkgs_cmdln_tools}

read -p "Enter 'y' to continue [nY]: " response
#if [ "n" = "${response}" ] || [ "N" = "${response}" ] ; then
if [ -n "$(echo ${response} | grep -e '^[Nn].*')" ] ; then
  exit ;
fi
#apt-get [--simulate] -y install pkg0 .. pkgN # ERR, doesn't skip missing
for pkgX in ${pkgs_cmdln_tools} ; do
  apt-get -y install ${pkgX} ;
done

#dbus-uuidgen --ensure[=/etc/machine-id]
if [ ! -z "$(grep 0000 /etc/hostname)" ] ; then
  #idsuffix=$(cat /etc/machine-id | cut -b29-32) ;
  idsuffix=$(cat /var/lib/dbus/machine-id | cut -b29-32) ;
  for fileX in /etc/hosts /etc/hostname /etc/sysconfig/network ; do
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

#chgrp [postfix | mail] /var/mail ; chmod [g+ws,+t | 3775] /var/mail
chgrp postfix /var/mail ; chmod g+ws,+t /var/mail

(cd /etc/skel ; mkdir -p .gnupg .ssh .pki)
(cd /root/init/common ; cp -a skel/_gnupg/* /etc/skel/.gnupg/ ; \
  cp -a skel/_ssh/* /etc/skel/.ssh/ ; cp -a skel/_pki/* /etc/skel/.pki/ ; \
  cp -a skel/_gitconfig.sample /etc/skel/.gitconfig ; \
  cp -a skel/_hgrc.sample /etc/skel/.hgrc)


set +e ; set +u
touch /var/log/messages

#mkdir -p /var/lib/clamav ; chown -R clamav:clamav /var/lib/clamav
#touch /var/lib/clamav/clamd.sock

# Only add the secure path line if it is not already present
#grep -q 'secure_path' /etc/sudoers \
#  || sed -i '/Defaults\s\+env_reset/a Defaults\tsecure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"' /etc/sudoers

if [ -n "$(lspci | grep -ie wireless)" ] ; then
  psk=$(wpa_passphrase ${SSID:-HOME24-WIFI} ${passphrase:-abcd0123} | sed -n 's|^[[:space:]]*psk=\(.*\)|\1|p')
  nmcli device wifi list ; sleep 3
  nmcli device wifi connect ${SSID:-HOME24-WIFI} password ${psk}
  #nmcli device connection up ${SSID:-HOME24-WIFI}
  # see /etc/NetworkManager/system-connections/*
fi

sh /root/init/common/cron/linux/config_cron.sh

smtp_daemon=${smtp_daemon:-postfix}
# config postfix -- maildir format vice mbox
chkconfig --add postfix || true ; service restart postfix || true
# [home_mailbox=Maildir/ | mail_spool_directory=/var/spool/mail/]
#echo "mail_spool_directory = /var/spool/mail/" >> /etc/postfix/main.cf
postconf mail_spool_directory=/var/spool/mail/
postfix reload
for userX in root packer vagrant ; do
  [ ! -e /var/mail/${userX}.old ] && \
    mv /var/mail/${userX} /var/mail/${userX}.old ;
done
mkdir -p /var/mail/postfix ; chown postfix:postfix /var/mail/postfix
(cd /var/mail ; ln -s postfix root)

firewall_tool=${firewall_tool:-iptables-nft}
##drakfirewall ; sleep 600
sh /root/init/common/firewall/linux/config_iptables.sh #config_iptables allow
#for ruleset in iptables.rules ip6tables.rules ; do
#  diff -s /etc/iptables/${ruleset} /etc/iptables/${ruleset}.new ;
#done
#(sleep 120 && (iptables-nft -F ; iptables-nft -X ; ip6tables-nft -F ; \
#  ip6tables-nft -X))& && (iptables-nft-restore /etc/iptables/iptables.rules ; \
#  ip6tables-nft-restore /etc/iptables/ip6tables.rules)
(iptables-nft-restore /etc/iptables/iptables.rules ; \
  ip6tables-nft-restore /etc/iptables/ip6tables.rules)

if [ -z "$(grep -e 'domain.*mdns' /etc/ipset.conf)" ] ; then
  #ip[6]tables-nft -A In_allow -p udp -m multiport --dports domain,mdns -j ACCEPT ;
  sed -i 's|domain|domain,mdns|g' /etc/ipset.conf ;
fi
#ipset list ; sleep 5
iptables-nft -L ; sleep 5 ; ip6tables-nft -L ; sleep 5


set -e ; set -u
sh /root/init/common/misc_config.sh cfg_nsswitch_mdns
sh /root/init/common/misc_config.sh cfg_sudo_nopasswd /etc/sudoers.d
sh /root/init/common/misc_config.sh cfg_inputrc_histsearch
#sh /root/init/common/misc_config.sh check_clamav
sh /root/init/common/misc_config.sh cfg_sshd
sh /root/init/common/misc_config.sh cfg_shell_keychain
sh /root/init/common/misc_config.sh share_nfs_data0 ${SHAREDNODE}
#sh /root/init/common/misc_config.sh cfg_printer_pdf
#sh /root/init/common/misc_config.sh cfg_printer_default ${SHAREDNODE} ${PRINTNAME}
lpstat -t || true ; sleep 5

set +e ; set +u
echo "Enable|disable services" ; sleep 3
for svc in ${services_enabled} ; do
  chkconfig --add ${svc} || true ;
done
for svc in ${services_disabled} ; do
  chkconfig --del ${svc} || true ;
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
