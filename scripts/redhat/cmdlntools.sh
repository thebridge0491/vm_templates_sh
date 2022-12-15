#!/bin/sh -eux

export SHAREDNODE=${1:-localhost.local} ; export PRINTNAME=${2:-printer1}

set +e

dnf -y install epel-release ; dnf -y check-update ; dnf -y upgrade
. /root/init/redhat/distro_pkgs.ini
dnf --setopt=install_weak_deps=False config-manager --save
dnf config-manager --dump | grep -we install_weak_deps
dnf --setopt=install_weak_deps=False -y install $pkgs_cmdln_tools
dnf -y groups mark convert

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
	last4=$(cat /etc/machine-id | cut -b29-32) ;
	#last4=$(cat /var/lib/dbus/machine-id | cut -b29-32) ;
	init_hostname=$(cat /etc/hostname) ;
	NAME=$(echo ${init_hostname} | sed "s|0000|${last4}|") ;
	echo "${NAME}" > /etc/hostname ;
	sed -i "/${init_hostname}/ s|${init_hostname}|${NAME}|g" /etc/hosts ;
	sed -i "/${init_hostname}/ s|${init_hostname}|${NAME}|" \
		/etc/sysconfig/network ;
fi

set +e ; set +u
dnf group list -v hidden ; sleep 5
dnf --setopt=install_weak_deps=False -y group install base

#ntpd -u ntp:ntp ; ntpq -p ; sleep 3
#systemctl enable ntpd.service
systemctl enable chronyd.service

sh /root/init/common/linux/firewall/firewalld/config_firewalld.sh cmds_firewalld allow
systemctl unmask firewalld.service ; systemctl enable firewalld.service

#sed -i 's|^Example|#Example|' /etc/freshclam.conf
#sed -i 's|^Example|#Example|' /etc/clamd.d/scan.conf
#sed -i 's|^#\s*LocalSocket|LocalSocket|' /etc/clamd.d/scan.conf
#sh /root/init/common/misc_config.sh check_clamav
#systemctl enable clamd@ ; systemctl enable clamav-freshclam


systemctl enable avahi-daemon ; systemctl enable nfs-utils
systemctl enable cups ; systemctl enable cups-browsed

#sh /root/init/common/misc_config.sh cfg_printer_default $SHAREDNODE $PRINTNAME
sh /root/init/common/misc_config.sh cfg_printer_pdf \
    /usr/share/cups/model/CUPS-PDF.ppd /etc/cups/cups-pdf.conf
firewall-cmd --zone=public --permanent --add-service=mdns
set -e ; set -u

sed -i "/^%wheel.*(ALL)\s*ALL/ s|%sudo|# %sudo|" /etc/sudoers
#sed -i "/^#.*%wheel.*NOPASSWD.*/ s|^#.*%wheel|%wheel|" /etc/sudoers
if [ -z "$(grep '^%wheel ALL=(ALL) NOPASSWD: ALL' /etc/sudoers)" ] ; then
	echo '%wheel ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers ;
fi
sed -i "s|^[^#].*requiretty|# Defaults requiretty|" /etc/sudoers

sh /root/init/common/misc_config.sh cfg_sshd
#sh /root/init/common/misc_config.sh cfg_shell_keychain
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
distro="$(rpm -qf --queryformat '%{NAME}' /etc/redhat-release | cut -f 1 -d '-')"

# Remove development and kernel source packages
#dnf -y remove gcc cpp kernel-devel kernel-headers perl

if [ "$distro" != 'redhat' ] ; then
  dnf -y clean all ;
fi
