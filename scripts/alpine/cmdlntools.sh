#!/bin/sh -eux

export SHAREDNODE=${1:-localhost.local} ; export PRINTNAME=${2:-printer1}

set +e
#set -e

apk update ; apk upgrade -U -a
. /root/init/alpine/distro_pkgs.ini
apk add ${pkgs_cmdln_tools}

if [ -z "$(grep '^export JAVA_HOME' /etc/bash.bashrc)" ] ; then
  echo "export JAVA_HOME=${default_java_home}" >> /etc/bash.bashrc ;
fi
mkdir -p ${default_java_home}
if [ -z "$(grep '^JAVA_VERSION' ${default_java_home}/release)" ] ; then
  echo JAVA_VERSION="${default_java_version}" >> ${default_java_home}/release ;
fi

#rc-update add sshd default

service dbus start
if [ ! -z "$(grep 0000 /etc/hostname)" ] ; then
	last4=$(cat /etc/machine-id | cut -b29-32) ;
	#last4=$(cat /var/lib/dbus/machine-id | cut -b29-32) ;
	init_hostname=$(cat /etc/hostname) ;
	NAME=$(echo ${init_hostname} | sed "s|0000|${last4}|") ;
	echo "${NAME}" > /etc/hostname ;
	sed -i "/${init_hostname}/ s|${init_hostname}|${NAME}|g" /etc/hosts ;
fi
if [ -z "$(grep -e 'dbus-uuidgen --ensure' /etc/local.d/machineid-save.start)" ] ; then
  #echo dbus-uuidgen --ensure=/var/lib/dbus/machine-id >> \
  #  /etc/local.d/machineid-save.start ;
  echo dbus-uuidgen --ensure=/etc/machine-id >> \
    /etc/local.d/machineid-save.start ;
  chmod +x /etc/local.d/machineid-save.start ;
  rc-update add local default ;
fi


set +e ; set +u
ntpd -u ntp:ntp ; ntpq -p ; sleep 3
rc-update add openntpd default

sh /root/init/common/linux/firewall/nftables/config_nftables.sh cmds_nftables allow	# cmds | config
#ipset flush ; iptables -F ; ip6tables -F
#ipset destroy ; iptables -X ; ip6tables -X
for unit in ipset iptables ip6tables ; do
	service ${unit} stop ;
	rc-update del ${unit} default ;
done
service nftables save
rc-update add nftables default


#mkdir -p /var/lib/clamav ; chown -R clamav:clamav /var/lib/clamav
#touch /var/lib/clamav/clamd.sock
#sh /root/init/common/misc_config.sh check_clamav
#rc-update add freshclam default ; rc-update add clamd default
set -e ; set -u


#sed -i '/hosts:/ s|files|files mdns_minimal \[NOTFOUND=return\]|' /etc/nsswitch.conf

for svc in dbus cupsd avahi-daemon ; do
  rc-update add ${svc} default
done

set +e
#sh /root/init/common/misc_config.sh cfg_printer_default ${SHAREDNODE} ${PRINTNAME}
sh /root/init/common/misc_config.sh cfg_printer_pdf \
  /usr/share/cups/model/CUPS-PDF_opt.ppd /etc/cups/cups-pdf.conf
#nft add rule inet filter in_allow udp port mdns accept
sed -i 's|domain|domain, mdns|g' /etc/nftables.conf
sed -i 's|domain|domain, mdns|g' /etc/nftables/*nftables.conf
#iptables -A In_allow -p udp -m multiport --dports mdns -j ACCEPT
#ip6tables -A In_allow -p udp -m multiport --dports mdns -j ACCEPT
#sed -i 's|domain|domain, mdns|g' /etc/ipset.conf

set -e

#sed -i "/PermitRootLogin/ s|^\(.*\)$|PermitRootLogin no|" /etc/ssh/sshd_config
sed -i "/^%wheel.*(ALL)\s*ALL/ s|%wheel|# %wheel|" /etc/sudoers
sed -i "/^#.*%wheel.*NOPASSWD.*/ s|^#.*%wheel|%wheel|" /etc/sudoers
if [ -z "$(grep '^%wheel ALL=(ALL) NOPASSWD: ALL' /etc/sudoers)" ] ; then
	echo '%wheel ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers ;
fi
sed -i "s|^[^#].*requiretty|# Defaults requiretty|" /etc/sudoers

sh /root/init/common/misc_config.sh cfg_sshd
sh /root/init/common/misc_config.sh cfg_shell_keychain
sh /root/init/common/misc_config.sh share_nfs_data0 ${SHAREDNODE}

(cd /etc/skel ; mkdir -p .gnupg .ssh .pki)
cp -R /root/init/common/skel/_gnupg/* /etc/skel/.gnupg/
cp -R /root/init/common/skel/_ssh/* /etc/skel/.ssh/
cp -R /root/init/common/skel/_pki/* /etc/skel/.pki/
cp /root/init/common/skel/_gitconfig.sample /etc/skel/.gitconfig
cp /root/init/common/skel/_hgrc.sample /etc/skel/.hgrc

sshca_pubkey="/etc/skel/.ssh/publish_krls/sshca-id_ed25519.pub"
sshca_krl="/etc/skel/.ssh/publish_krls/krl.krl"
if [ -e ${sshca_pubkey} ] ; then
	echo "@cert-authority 192.168.* $(cat ${sshca_pubkey})" >> \
		/etc/skel/.ssh/known_hosts ;
	cp ${sshca_krl} ${sshca_pubkey} /etc/ssh/ ;
fi


## scripts/cleanup.sh
apk -v cache clean
