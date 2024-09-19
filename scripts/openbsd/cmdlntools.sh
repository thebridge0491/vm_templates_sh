#!/bin/sh -eux

export sed_inplace="sed -i"
export SHAREDNODE=${1:-localhost.local} ; export PRINTNAME=${2:-printer1}

set +e

# fetch missing distribution sets like: xbase59.tgz
#arch=$(arch -s) ; rel=$(sysctl -n kern.osrelease)
#ftp http://cdn.openbsd.org/pub/OpenBSD/${rel}/${arch}/xbase59.tgz
#tar -C / -xpzf xbase59.tgz ; sysmerge

arch=$(arch -s) ; rel=$(sysctl -n kern.osrelease)
setVer=$(echo ${rel} | tr '.' '\0')
cd /tmp
for setX in xbase ; do
  ftp http://cdn.openbsd.org/pub/OpenBSD/${rel}/${arch}/${setX}${setVer}.tgz ;
  tar -C / -xpzf ${setX}${setVer}.tgz ;
done
sysmerge


pkg_add -u #; pkg_add -ziU mupdf
. /root/init/openbsd/distro_pkgs.ini
pkg_add -ziU -n ${pkgs_cmdln_tools} ; pkg_add -ziU ${pkgs_cmdln_tools}

if [ -z "$(grep '^export JAVA_HOME' /etc/ksh.kshrc)" ] ; then
  echo "export JAVA_HOME=${default_java_home}" >> /etc/ksh.kshrc ;
fi
if [ -z "$(grep '^fdesc' /etc/fstab)" ] ; then
  echo 'fdesc  /dev/fd  fdescfs  rw  0  0' >> /etc/fstab ;
fi

if [ ! -z "$(grep 0000 /etc/myname)" ] ; then
	#last4=$(cat /etc/hostid | cut -b33-36) ;
	last4=$(sysctl -n hw.uuid | cut -b33-36) ;
	init_hostname=$(hostname) ;
	NAME=$(echo ${init_hostname} | sed "s|0000|${last4}|") ;
	echo "${NAME}" > /etc/myname ;
	sed -i "/${init_hostname}/ s|${init_hostname}|${NAME}|g" /etc/hosts ;
fi

set +e ; set +u

#rcctl enable ntpd
# Set the time correctly
#ntpd -u ntp:ntp ; ntpq -p ; sleep 3
ntpdate -v -u -b us.pool.ntp.org

pfctl -d
rcctl enable pf
rcctl enable pflogd
sh /root/init/common/bsd/firewall/pf/pfconf.sh config_pf allow >> /etc/pf.conf
pfctl -vf /etc/pf.conf ; pfctl -s info ; sleep 5 ; pfctl -s rules -a '*'
sleep 5

#rcctl enable freshclam
#rcctl enable clamd
#sh /root/init/common/misc_config.sh check_clamav

rcctl enable sshd
rcctl enable messagebus
rcctl enable lpd
rcctl enable cupsd
rcctl enable cups_browsed

rcctl enable avahi_daemon

#sed -i '/hosts:/ s| dns| mdns_minimal \[NOTFOUND=return\] dns mdns|' /etc/nsswitch.conf
sed -i '/hosts:/ s|files|files mdns_minimal \[NOTFOUND=return\]|' /etc/nsswitch.conf

#usermod -G cups root

#sh /root/init/common/misc_config.sh cfg_printer_default ${SHAREDNODE} ${PRINTNAME}
sh /root/init/common/misc_config.sh cfg_printer_pdf \
  /usr/local/share/cups/model/CUPS-PDF_opt.ppd /etc/cups/cups-pdf.conf
#echo 'pass in proto udp from any to any port { mdns } keep state' >> /etc/pf/outallow_in_allow.rules
sed -i 's|domain|domain, mdns|g' /etc/pf/outallow_in_allow.rules
set -e ; set -u


# As sharedfolders are not in defaults ports tree, we will use NFS sharing
#rcctl enable rpcbind
#rcctl enable nfsd
#rcctl enable mountd

sed -i "/PermitRootLogin/ s|^\(.*\)$|PermitRootLogin no|" /etc/ssh/sshd_config
sed -i "/^%wheel.*(ALL)\s*ALL/ s|%wheel|# %wheel|" /etc/sudoers
sed -i "/^#.*%wheel.*NOPASSWD.*/ s|^#.*%wheel|%wheel|" /etc/sudoers
if [ -z "$(grep '^%wheel ALL=(ALL) NOPASSWD: ALL' /etc/sudoers)" ] ; then
	echo '%wheel ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers ;
fi
sed -i "s|^[^#].*requiretty|# Defaults requiretty|" /etc/sudoers

sh /root/init/common/misc_config.sh cfg_sshd
sh /root/init/common/misc_config.sh cfg_shell_keychain /etc/skel/.cshrc
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
