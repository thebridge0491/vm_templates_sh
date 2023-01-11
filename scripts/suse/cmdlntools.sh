#!/bin/sh -eux

export SHAREDNODE=${1:-localhost.local} ; export PRINTNAME=${2:-printer1}

set +e ; set +u
zypper --non-interactive refresh ; zypper --non-interactive update
zypper --non-interactive remove netcat-openbsd
. /root/init/suse/distro_pkgs.ini
sed -i 's|.*solver.onlyRequires.*=.*|solver.onlyRequires = true|' \
  /etc/zypp/zypp.conf
sed -i 's|.*installRecommends.*=.*|installRecommends = no|' \
  /etc/zypp/zypper.conf
zypper --non-interactive install --no-recommends $pkgs_cmdln_tools

zypper search --type pattern ; sleep 5
for pat in enhanced_base apparmor sw_management ; do
    zypper --non-interactive install --no-recommends -t pattern $pat ;
done

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
if [ ! -e /etc/systemd/system/machineid-save.service ] ; then
  cat << EOF > /etc/systemd/system/machineid-save.service ;
[Unit]
Before=network.target
[Service]
Type=oneshot
ExecStart=/usr/bin/dbus-uuidgen --ensure
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target

EOF
fi
systemctl enable machineid-save.service ;


ntpd -u ntp:ntp ; ntpq -p ; sleep 3
systemctl enable ntpd.service

#sh /tmp/firewall/SuSEfirewall2/config_SuSEfirewall2.sh cmds_SuSEfirewall2
#systemctl enable SuSEfirewall2.service
sh /root/init/common/linux/firewall/firewalld/config_firewalld.sh cmds_firewalld allow
systemctl unmask firewalld.service ; systemctl enable firewalld.service

#sh /root/init/common/misc_config.sh check_clamav
#systemctl enable freshclam.service ; systemctl enable clamd.service


#sh /root/init/common/misc_config.sh cfg_printer_default $SHAREDNODE $PRINTNAME
sh /root/init/common/misc_config.sh cfg_printer_pdf \
    /usr/share/cups/model/CUPS-PDF_opt.ppd /etc/cups/cups-pdf.conf
#yast firewall services add zone=EXT service=service:avahi
firewall-cmd --zone=public --permanent --add-service=mdns
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
zypper --non-interactive clean ;

## scripts/zypper-locks.sh
# remove zypper locks on removed packages to avoid later dependency problems
zypper --non-interactive rl \*
