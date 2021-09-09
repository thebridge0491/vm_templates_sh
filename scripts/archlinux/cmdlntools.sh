#!/bin/sh -eux

export SHAREDNODE=${1:-localhost.local} ; export PRINTNAME=${2:-printer1}

svc_enable() {
  svc=${1}
  if command -v systemctl > /dev/null ; then
    systemctl enable $svc ;
  elif command -v s6-rc > /dev/null ; then
    s6-rc-bundle-update add default $svc ;
  elif command -v sv > /dev/null ; then
    ln -s /etc/runit/sv/$svc /run/runit/service ;
  elif command -v rc-update > /dev/null ; then
  	rc-update add $svc default ;
  fi
}

set +e
if command -v systemctl > /dev/null ; then
  systemctl stop pamac.service ;
elif command -v s6-rc > /dev/null ; then
  s6-rc -d change pamac ;
elif command -v sv > /dev/null ; then
  sv down pamac ;
elif command -v rc-update > /dev/null ; then
  rc-service pamac stop ;
fi
rm /var/lib/pacman/db.lck
#set -e

pacman --noconfirm -Syy ; pacman --noconfirm -Syu
. /root/init/archlinux/distro_pkgs.ini
pacman --noconfirm --needed -S $pkgs_cmdln_tools

if [ -f /etc/os-release ] ; then
  . /etc/os-release ;
elif [ -f /usr/lib/os-release ] ; then
  . /usr/lib/os-release ;
fi
if command -v s6-rc > /dev/null ; then
  service_mgr=s6 ;
elif command -v sv > /dev/null ; then
  service_mgr=runit ;
elif command -v rc-update > /dev/null ; then
  service_mgr=openrc ;
fi

if [ "artix" = "${ID}" ] ; then
  for pkgX in ntp nftables avahi nfs-utils cups ; do
    pacman --noconfirm --needed -S ${pkgX}-${service_mgr} ;
  done ;
fi

if [ -z "$(grep '^export JAVA_HOME' /etc/bash.bashrc)" ] ; then
  echo "export JAVA_HOME=${default_java_home}" >> /etc/bash.bashrc ;
fi
mkdir -p ${default_java_home}
if [ -z "$(grep '^JAVA_VERSION' ${default_java_home}/release)" ] ; then
  echo JAVA_VERSION="${default_java_version}" >> ${default_java_home}/release ;
fi

#svc_enable sshd #; svc_enable sshd.socket

#dbus-uuidgen --ensure[=/etc/machine-id]
if [ ! -z "$(grep 0000 /etc/hostname)" ] ; then
	#last4=$(cat /etc/machine-id | cut -b29-32) ;
	last4=$(cat /var/lib/dbus/machine-id | cut -b29-32) ;
	init_hostname=$(cat /etc/hostname) ;
	NAME=$(echo ${init_hostname} | sed "s|0000|${last4}|") ;
	echo "${NAME}" > /etc/hostname ;
	sed -i "/${init_hostname}/ s|${init_hostname}|${NAME}|g" /etc/hosts ;
fi

set +e ; set +u
ntpd -u ntp:ntp ; ntpq -p ; sleep 3
svc_enable ntpd

sh /root/init/common/linux/firewall/nftables/config_nftables.sh cmds_nftables allow	# cmds | config
#ipset flush ; iptables -F ; ip6tables -F
#ipset destroy ; iptables -X ; ip6tables -X
for unit in ipset iptables ip6tables ; do
  if command -v systemctl > /dev/null ; then
    systemctl stop $unit ; systemctl disable $unit ;
  elif command -v s6-rc > /dev/null ; then
    s6-rc -d change $unit ; s6-rc-bundle-update delete default $unit ;
  elif command -v sv > /dev/null ; then
    sv stop $unit ; rm /run/runit/service/$unit ;
  elif command -v rc-update > /dev/null ; then
    rc-service stop $unit ; rc-update del $unit default ;
  fi ;
  if command -v systemctl > /dev/null ; then
    systemctl mask $unit ;
  fi ;
done
if command -v systemctl > /dev/null ; then
  systemctl unmask nftables ;
fi
svc_enable nftables


#mkdir -p /var/lib/clamav ; touch /var/lib/clamav/clamd.sock
#chown clamav:clamav /var/lib/clamav/clamd.sock
#sh /root/init/common/misc_config.sh check_clamav
#svc_enable freshclamd ; svc_enable clamd
set -e ; set -u


sed -i '/hosts:/ s|files|files mdns_minimal \[NOTFOUND=return\]|' /etc/nsswitch.conf

for svc in cupsd org.cups.cupsd cups-browsed avahi-daemon nfsclient ; do
    svc_enable $svc ;
done

set +e
#sh /root/init/common/misc_config.sh cfg_printer_default $SHAREDNODE $PRINTNAME
sh /root/init/common/misc_config.sh cfg_printer_pdf \
    /usr/share/cups/model/CUPS-PDF_opt.ppd /etc/cups/cups-pdf.conf
#nft add rule inet filter in_allow udp port mdns accept
sed -i 's|domain|domain, mdns|g' /etc/nftables.conf
sed -i 's|domain|domain, mdns|g' /etc/nftables/*nftables.conf
#iptables -A In_allow -p udp -m multiport --dports mdns -j ACCEPT
#ip6tables -A In_allow -p udp -m multiport --dports mdns -j ACCEPT
#sed -i 's|domain|domain, mdns|g' /etc/ipset.conf

set -e

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
cp /root/init/common/skel/_gitconfig /etc/skel/.gitconfig
cp /root/init/common/skel/_hgrc /etc/skel/.hgrc

sshca_pubkey="/etc/skel/.ssh/publish_krls/sshca-id_ed25519.pub"
sshca_krl="/etc/skel/.ssh/publish_krls/krl.krl"
if [ -e $sshca_pubkey ] ; then
	echo "@cert-authority 192.168.* $(cat $sshca_pubkey)" >> \
		/etc/skel/.ssh/known_hosts ;
	cp $sshca_krl $sshca_pubkey /etc/ssh/ ;
fi


## scripts/cleanup.sh
pacman --noconfirm -Sc
