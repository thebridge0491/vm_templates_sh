#!/bin/sh -eux

export SED_INPLACE="sed -i"
export SHAREDNODE=${1:-localhost.local} ; export PRINTNAME=${2:-printer1}

svc_enable() {
  svc=${1}
  if command -v systemctl > /dev/null ; then
    systemctl enable $svc ;
  elif command -v update-rc.d > /dev/null ; then
  	update-rc.d $svc defaults ;
  fi
}

set +e

. /root/init/debian/distro_pkgs.ini
apt-config dump | grep -we Recommends -e Suggests | sed 's|1|0|' | \
  tee /etc/apt/apt.conf.d/999norecommends
apt-get -y --no-install-recommends install $pkgs_cmdln_tools
tasksel --list-tasks ; sleep 5

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
	hostname --file /etc/hostname ;
fi


set +e ; set +u
#svc_enable ssh ; svc_enable ntp
#svc_enable ufw
#svc_enable clamav-freshclam

ntpd -u ntp:ntp ; ntpq -p ; sleep 3

##ufw disable
#sh /root/init/common/linux/firewall/ufw/config_ufw.sh cmds_ufw allow
#svc_enable nftables
sh /root/init/common/linux/firewall/nftables/config_nftables.sh config_nftables allow	# cmds | config
#ipset flush ; iptables -F ; ip6tables -F
#ipset destroy ; iptables -X ; ip6tables -X
for unit in ipset iptables ip6tables ; do
  if command -v systemctl > /dev/null ; then
    systemctl stop $unit ; systemctl disable $unit ;
  elif command -v update-rc.d > /dev/null ; then
    service $unit stop ; update-rc.d $unit remove ;
  fi ;
  if command -v systemctl > /dev/null ; then
    systemctl mask $unit ;
  fi ;
done
if command -v systemctl > /dev/null ; then
  systemctl unmask nftables ;
fi

#sh /root/init/common/misc_config.sh check_clamav


# service(s) enabled by package install trigger: [e]udev, dbus, mdns (avahi)
# svc_enable udev ; svc_enable eudev ; svc_enable dbus ; svc_enable avahi-daemon

#sed -i '/hosts:/ s|files dns|files mdns_minimal \[NOTFOUND=return\] dns mdns|' /etc/nsswitch.conf
sed -i '/hosts:/ s|files dns|files mdns_minimal \[NOTFOUND=return\] dns|' /etc/nsswitch.conf
#ufw allow in svc MDNS
#nft add rule inet filter in_allow udp port mdns accept
sed -i 's|domain|domain, mdns|g' /etc/nftables.conf
sed -i 's|domain|domain, mdns|g' /etc/nftables/*nftables.conf


(cd /etc/skel ; mkdir -p .gnupg .pki .ssh)
cp -R /root/init/common/skel/_gnupg/* /etc/skel/.gnupg/
cp -R /root/init/common/skel/_pki/* /etc/skel/.pki/
cp -R /root/init/common/skel/_ssh/* /etc/skel/.ssh/
cp /root/init/common/skel/_gitconfig /etc/skel/.gitconfig
cp /root/init/common/skel/_hgrc /etc/skel/.hgrc

if [ "$(grep '^.*%sudo.*ALL.*NOPASSWD.*' /etc/sudoers)" ] ; then
  sed -i "s|^.*%sudo.*ALL.*NOPASSWD.*|%sudo ALL=(ALL) NOPASSWD: ALL|" /etc/sudoers ;
else
	echo '%sudo ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers ;
fi
sed -i "s|^[^#].*requiretty|# Defaults requiretty|" /etc/sudoers

# Only add the secure path line if it is not already present
grep -q 'secure_path' /etc/sudoers \
  || sed -i '/Defaults\s\+env_reset/a Defaults\tsecure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"' /etc/sudoers

sh /root/init/common/misc_config.sh cfg_sshd /etc/skel/.ssh
sh /root/init/common/misc_config.sh cfg_shell_keychain /etc/skel/.bashrc


svc_enable nfs-common
sh /root/init/common/misc_config.sh share_nfs_data0 $SHAREDNODE


#svc_enable cups ; svc_enable cups-browsed
#sh /root/init/common/misc_config.sh cfg_printer_pdf /etc/cups \
#    /usr/share/ppd/cups-pdf
##sh /root/init/common/misc_config.sh cfg_printer_default $SHAREDNODE $PRINTNAME
lpstat -t ; sleep 5
set -e ; set -u


## scripts/cleanup.sh
apt-get -y clean
