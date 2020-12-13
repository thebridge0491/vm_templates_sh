#!/bin/sh -eux

#set path = (~/bin /bin /sbin /usr/{bin,sbin,X11R7/bin,pkg/{,s}bin,games} \
#			/usr/local/{,s}bin)
export PATH=$HOME/bin:/bin:/sbin:/usr/bin:/usr/sbin:/usr/X11R7/bin:/usr/pkg/bin:/usr/pkg/sbin:/usr/pkg/games:/usr/local/bin:/usr/local/sbin

set +x
export sed_inplace="sed -i"
export SHAREDNODE=${1:-localhost.local} ; export PRINTNAME=${2:-printer1}

set +e

# fetch missing distribution sets like: xbase.tar.xz
#arch=$(uname -m) ; rel=$(sysctl -n kern.osrelease)
#ftp http://cdn.netbsd.org/pub/NetBSD/NetBSD-${rel}/${arch}/binary/sets/xbase.tar.xz
#tar -C / -xpJf xbase.tar.xz

arch=$(uname -m) ; rel=$(sysctl -n kern.osrelease)
cd /tmp
for setX in xbase ; do
  ftp http://cdn.netbsd.org/pub/NetBSD/NetBSD-${rel}/${arch}/binary/sets/${setX}.tar.xz ;
  tar -C / -xpJf ${setX}.tar.xz ;
done


pkgin update ; pkgin -y upgrade
. /root/init/netbsd/distro_pkgs.ini
pkgin -yd install $pkgs_cmdln_tools ; pkgin -y install $pkgs_cmdln_tools

if [ -z "$(grep '^export JAVA_HOME' /etc/csh.cshrc)" ] ; then
  echo "export JAVA_HOME=${default_java_home}" >> /etc/csh.cshrc ;
fi
if [ -z "$(grep '^fdesc' /etc/fstab)" ] ; then
  echo 'fdesc  /dev/fd  fdescfs  rw  0  0' >> /etc/fstab ;
fi

# clamd freshclamd
for svc in dbus avahidaemon cupsd ; do
	cp /usr/pkg/share/examples/rc.d/$svc /etc/rc.d/ ;
done
mkdir -p /var/run/dbus

if [ ! -z "$(sysctl -n kern.hostname | grep 0000)" ] ; then
	#last4=$(cat /etc/hostid | cut -b33-36) ;
	last4=$(sysctl -n machdep.dmi.system-uuid | cut -b33-36) ;
	init_hostname=$(hostname) ;
	NAME=$(echo ${init_hostname} | sed "s|0000|${last4}|") ;
	sed -i "/${init_hostname}/ s|${init_hostname}|${NAME}|" /etc/rc.conf ;
	sed -i "/${init_hostname}/ s|${init_hostname}|${NAME}|g" /etc/hosts ;
fi

set +e ; set +u

#echo 'ntpd=YES' >> /etc/rc.conf
# Set the time correctly
#ntpd -u ntp:ntp ; ntpq -p ; sleep 3
ntpdate -v -u -b us.pool.ntp.org

pfctl -d
echo 'pf=YES' >> /etc/rc.conf
echo 'pflogd=YES' >> /etc/rc.conf
sh /root/init/common/bsd/firewall/pf/pfconf.sh config_pf allow >> /etc/pf.conf
sed -i '/icmp6 / s|icmp6 |ipv6-icmp |' /etc/pf/outallow_in_allow.rules
sed -i '/icmp6 / s|icmp6 |ipv6-icmp |' /etc/pf/outdeny_out_allow.rules
pfctl -vf /etc/pf.conf ; pfctl -s info ; sleep 5 ; pfctl -s rules -a '*'
sleep 5

#echo 'freshclamd=YES' >> /etc/rc.conf
#echo 'clamd=YES' >> /etc/rc.conf
#sh /root/init/common/misc_config.sh check_clamav

#echo 'sshd=YES' >> /etc/rc.conf

# clamd freshclamd
for svc in dbus avahidaemon cupsd lpd ; do
	echo "${svc}=YES" >> /etc/rc.conf ;
done

#sed -i '/hosts:/ s| dns| mdns_minimal \[NOTFOUND=return\] dns mdns|' /etc/nsswitch.conf
sed -i '/hosts:/ s|files|files mdns_minimal \[NOTFOUND=return\]|' /etc/nsswitch.conf

#usermod -G cups root

#sh /root/init/common/misc_config.sh cfg_printer_default $SHAREDNODE $PRINTNAME
sh /root/init/common/misc_config.sh cfg_printer_pdf \
    /usr/pkg/share/cups/model/CUPS-PDF.ppd /usr/pkg/etc/cups/cups-pdf.conf
#echo 'pass in proto udp from any to any port { mdns } keep state' >> /etc/pf/outallow_in_allow.rules
sed -i 's|domain|domain, mdns|g' /etc/pf/outallow_in_allow.rules
set -e ; set -u


# As sharedfolders are not in defaults ports tree, we will use NFS sharing
#echo 'rpcbind=YES' >> /etc/rc.conf
#echo 'nfsd=YES' >> /etc/rc.conf
#echo 'mountd=YES' >> /etc/rc.conf

sed -i "/PermitRootLogin/ s|^\(.*\)$|PermitRootLogin no|" /etc/ssh/sshd_config
sed -i "/^%wheel.*(ALL)\s*ALL/ s|%wheel|# %wheel|" /usr/pkg/etc/sudoers
sed -i "/^#.*%wheel.*NOPASSWD.*/ s|^#.*%wheel|%wheel|" /usr/pkg/etc/sudoers
if [ -z "$(grep '^%wheel ALL=(ALL) NOPASSWD: ALL' /usr/pkg/etc/sudoers)" ] ; then
	echo '%wheel ALL=(ALL) NOPASSWD: ALL' >> /usr/pkg/etc/sudoers ;
fi
sed -i "s|^[^#].*requiretty|# Defaults requiretty|" /usr/pkg/etc/sudoers

sh /root/init/common/misc_config.sh cfg_sshd
sh /root/init/common/misc_config.sh cfg_shell_keychain /etc/skel/.cshrc
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
