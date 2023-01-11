#!/bin/sh -eux

export SED_INPLACE="sed -i"
export SHAREDNODE=${1:-localhost.local} ; export PRINTNAME=${2:-printer1}

set +e
#set -e

. /root/init/void/distro_pkgs.ini
for pkgX in $pkgs_cmdln_tools ; do
	xbps-install -y -D $pkgX ;
done
for pkgX in $pkgs_cmdln_tools ; do
	xbps-install -y $pkgX ;
done

if [ -z "$(grep '^export JAVA_HOME' /etc/bash.bashrc)" ] ; then
  echo "export JAVA_HOME=${default_java_home}" >> /etc/bash.bashrc ;
fi
mkdir -p ${default_java_home}
if [ -z "$(grep '^JAVA_VERSION' ${default_java_home}/release)" ] ; then
  echo JAVA_VERSION="${default_java_version}" >> ${default_java_home}/release ;
fi

#dbus-uuidgen --ensure[=/etc/machine-id]
if [ "$(hostname | grep -e 'box.0000')" ] ; then
	last4=$(cat /var/lib/dbus/machine-id | cut -b29-32) ; # cat /etc/machine-id
	for fileX in /etc/hosts /etc/hostname ; do
	  sed -i "/box.0000/ s|\(box.\)0000|\1${last4}|g" $fileX ;
	done ;
	hostname `cat /etc/hostname` ;
fi
if [ -z "$(grep -e 'dbus-uuidgen --ensure' /etc/rc.local)" ] ; then
  #echo dbus-uuidgen --ensure=/etc/machine-id >> /etc/rc.local ;
  echo dbus-uuidgen --ensure >> /etc/rc.local ;
  chmod +x /etc/rc.local ;
fi


set +e ; set +u
#ln -s /etc/sv/sshd /var/service/
ln -s /etc/sv/ntpd /var/service/
#ln -s /etc/sv/freshclamd /var/service/ ; ln -s /etc/sv/clamd /var/service/ # ??
ln -s /etc/sv/nftables /var/service/

ntpd -u ntp:ntp ; ntpq -p ; sleep 3

sh /root/init/common/linux/firewall/nftables/config_nftables.sh config_nftables allow	# cmds | config
#ipset flush ; iptables -F ; ip6tables -F
#ipset destroy ; iptables -X ; ip6tables -X
for unit in ipset iptables ip6tables ; do
	sv down $unit ;
	rm /var/service/$unit ;
done

#mkdir -p /var/lib/clamav ; touch /var/lib/clamav/clamd.sock
#chown clamav:clamav /var/lib/clamav/clamd.sock
#sh /root/init/common/misc_config.sh check_clamav


for svc in dbus avahi-daemon ; do
    ln -s /etc/sv/$svc /var/service/ ;
done

#sed -i '/hosts:/ s|files dns|files mdns_minimal \[NOTFOUND=return\] dns mdns|' /etc/nsswitch.conf
sed -i '/hosts:/ s|files dns|files mdns_minimal \[NOTFOUND=return\] dns|' /etc/nsswitch.conf
#iptables -A In_allow -p udp -m multiport --dports mdns -j ACCEPT
#ip6tables -A In_allow -p udp -m multiport --dports mdns -j ACCEPT
#sed -i 's|domain|domain, mdns|g' /etc/ipset.conf
#nft add rule inet filter in_allow udp port mdns accept
sed -i 's|domain|domain, mdns|g' /etc/nftables.conf
sed -i 's|domain|domain, mdns|g' /etc/nftables/*nftables.conf


(cd /etc/skel ; mkdir -p .gnupg .ssh .pki)
cp -R /root/init/common/skel/_gnupg/* /etc/skel/.gnupg/
cp -R /root/init/common/skel/_ssh/* /etc/skel/.ssh/
cp -R /root/init/common/skel/_pki/* /etc/skel/.pki/
cp /root/init/common/skel/_gitconfig.sample /etc/skel/.gitconfig
cp /root/init/common/skel/_hgrc.sample /etc/skel/.hgrc
cat << EOF >> /etc/skel/.inputrc
"\e[A": history-search-backward
"\e[B": history-search-forward

EOF

if [ "$(grep '^.*%wheel.*ALL.*NOPASSWD.*' /etc/sudoers)" ] ; then
  sed -i "s|^.*%wheel.*ALL.*NOPASSWD.*|%wheel ALL=(ALL) NOPASSWD: ALL|" /etc/sudoers ;
else
	echo '%wheel ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers ;
fi
sed -i "s|^[^#].*requiretty|# Defaults requiretty|" /etc/sudoers

sh /root/init/common/misc_config.sh cfg_sshd /etc/skel/.ssh
sh /root/init/common/misc_config.sh cfg_shell_keychain /etc/skel/.bashrc


ln -s /etc/sv/rpcbind /var/service/
sh /root/init/common/misc_config.sh share_nfs_data0 $SHAREDNODE


for svc in cupsd ; do
    ln -s /etc/sv/$svc /var/service/ ;
done
#sh /root/init/common/misc_config.sh cfg_printer_pdf /etc/cups \
#    /usr/share/cups/model
##sh /root/init/common/misc_config.sh cfg_printer_default $SHAREDNODE $PRINTNAME
lpstat -t ; sleep 5
set -e ; set -u


## scripts/cleanup.sh
xbps-remove -O
