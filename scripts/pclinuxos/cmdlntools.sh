#!/bin/sh -eux

export SHAREDNODE=${1:-localhost.local} ; export PRINTNAME=${2:-printer1}

set +e

apt-get -y update
apt-get -y --fix-broken install
apt-get -y upgrade ; apt-get -y dist-upgrade
. /root/init/pclinuxos/distro_pkgs.ini
apt-get -y --option Retries=3 install $pkgs_cmdln_tools

if [ -z "$(grep '^export JAVA_HOME' /etc/bash.bashrc)" ] ; then
  echo "export JAVA_HOME=${default_java_home}" >> /etc/bash.bashrc ;
fi
mkdir -p ${default_java_home}
if [ -z "$(grep '^JAVA_VERSION' ${default_java_home}/release)" ] ; then
  echo JAVA_VERSION="${default_java_version}" >> ${default_java_home}/release ;
fi
#update-alternatives --get-selections
#update-alternatives --config [java | javac | jar | javadoc | javap | jdb | keytool]

#dbus-uuidgen --ensure[=/etc/machine-id]
if [ ! -z "$(grep 0000 /etc/hostname)" ] ; then
	#last4=$(cat /etc/machine-id | cut -b29-32) ;
	last4=$(cat /var/lib/dbus/machine-id | cut -b29-32) ;
	init_hostname=$(cat /etc/hostname) ;
	NAME=$(echo ${init_hostname} | sed "s|0000|${last4}|") ;
	echo "${NAME}" > /etc/hostname ;
	sed -i "/${init_hostname}/ s|${init_hostname}|${NAME}|g" /etc/hosts ;
	sed -i "/${init_hostname}/ s|${init_hostname}|${NAME}|" \
		/etc/sysconfig/network ;
fi


set +e ; set +u

ntpd -u ntp:ntp ; ntpq -p ; sleep 3
chkconfig --add ntpd

touch /var/log/messages
drakfirewall ; sleep 600 ; cat /etc/shorewall/rules.drakx ; sleep 5
#service shorewall stop ; service shorewall6 stop
## *** note ***: ipset version, incompatible w/ current kernel
#sh /root/init/common/linux/firewall/shorewall/config_shorewall.sh config_shorewall allow
##ipset flush ; iptables -F ; ip6tables -F
##ipset destroy ; iptables -X ; ip6tables -X
#for svc in ipset iptables ip6tables ; do
#	service $svc stop ;
#done


#sh /root/init/common/misc_config.sh check_clamav
#chkconfig --add freshclam ; chkconfig --add clamd


chkconfig --add avahi-daemon ; chkconfig --add nfs-common
chkconfig --add cups ; chkconfig --add cups-browsed

#sh /root/init/common/misc_config.sh cfg_printer_default $SHAREDNODE $PRINTNAME
sh /root/init/common/misc_config.sh cfg_printer_pdf \
    /usr/share/cups/model/CUPS-PDF_opt.ppd /etc/cups/cups-pdf.conf
chkconfig --add cups ; chkconfig --add cups-browsed
#iptables -A In_allow -p udp -m multiport --dports mdns -j ACCEPT
#ip6tables -A In_allow -p udp -m multiport --dports mdns -j ACCEPT
#sed -i 's|domain|domain, mdns|g' /etc/ipset.conf
shorewall save ; shorewall6 save #; shorewall restore ; shorewall6 restore
chkconfig --add shorewall ; chkconfig --add shorewall6
service shorewall status ; service shorewall6 status ; sleep 5
set -e ; set -u

sed -i "/^%wheel.*(ALL)\s*ALL/ s|%wheel|# %wheel|" /etc/sudoers
sed -i "/^#.*%wheel.*NOPASSWD.*/ s|^#.*%wheel|%wheel|" /etc/sudoers
if [ -z "$(grep '^%wheel ALL=(ALL) NOPASSWD: ALL' /etc/sudoers)" ] ; then
	echo '%wheel ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers ;
fi
sed -i "s|^[^#].*requiretty|# Defaults requiretty|" /etc/sudoers

sh /root/init/common/misc_config.sh cfg_sshd
sh /root/init/common/misc_config.sh cfg_shell_keychain
sh /root/init/common/misc_config.sh share_nfs_data0 $SHAREDNODE

(cd /etc/skel ; mkdir -p .gnupg .ssh .pki)
cp -R /root/init/common/skel/_gnupg/* /etc/skel/.gnupg/
cp -R /root/init/common/skel/_ssh/* /etc/skel/.ssh/
cp -R /root/init/common/skel/_pki/* /etc/skel/.pki/
cp /root/init/common/skel/_gitconfig.sample /etc/skel/.gitconfig
cp /root/init/common/skel/_hgrc.sample /etc/skel/.hgrc

sshca_pubkey="/etc/skel/.ssh/publish_krls/sshca-id_ed25519.pub"
sshca_krl="/etc/skel/.ssh/publish_krls/krl.krl"
if [ -e $sshca_pubkey ] ; then
	echo "@cert-authority 192.168.* $(cat $sshca_pubkey)" >> \
		/etc/skel/.ssh/known_hosts ;
	cp $sshca_krl $sshca_pubkey /etc/ssh/ ;
fi


## scripts/cleanup.sh
apt-get -y clean ;
