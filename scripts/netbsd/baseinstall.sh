#!/bin/sh -eux

# nc -l [-p] {port} > file ## nc -w3 {host} {port} < file  # netcat xfr
# ssh user@ipaddr "sudo sh -xs - arg1 argN" < script.sh  # w/ sudo
# ssh user@ipaddr "su -m root -c 'sh -xs - arg1 argN'" < script.sh

# passwd crypted hash: [md5|sha256|sha512] - [$1|$5|$6]$...
# python -c 'import crypt,getpass ; print(crypt.crypt(getpass.getpass(), "$6$16CHARACTERSSALT"))'
# perl -e 'print crypt("password", "\$6\$16CHARACTERSSALT") . "\n"'

#set path = (~/bin /bin /sbin /usr/{bin,sbin,X11R7/bin,pkg/{,s}bin,games} \
#			/usr/local/{,s}bin)
export PATH=$HOME/bin:/bin:/sbin:/usr/bin:/usr/sbin:/usr/X11R7/bin:/usr/pkg/bin:/usr/pkg/sbin:/usr/pkg/games:/usr/local/bin:/usr/local/sbin

set +x
export sed_inplace="sed -i"
PLAIN_PASSWD=${PLAIN_PASSWD:-abcd0123}
set -x
#CRYPTED_PASSWD=$(echo -n $PLAIN_PASSWD | python -c 'import sys,crypt ; print(crypt.crypt(sys.stdin.read(), "$6$16CHARACTERSSALT"))')

export SHAREDNODE=${1:-localhost.local} ; export PRINTNAME=${2:-printer1}

check_clamav() {
    freshclam --verbose ; sleep 3 ; freshclam --list-mirrors ; sleep 5
    ftp -S dont -o /tmp/eicar.com.txt https://secure.eicar.org/eicar.com.txt
    clamscan --verbose /tmp/eicar.com.txt ; sleep 5 ; clamscan --recursive /tmp
    rm /tmp/eicar.com.txt
}

set +e

# fetch missing distribution sets like: xbase.tgz
#arch=$(uname -m) ; rel=$(sysctl -n kern.osrelease)
#ftp http://cdn.netbsd.org/pub/NetBSD/NetBSD-${rel}/${arch}/binary/sets/xbase.tgz
#tar -C / -xpzf xbase.tgz


pkgin update ; pkgin -y upgrade
. /root/distro_pkgs.txt
pkgin -yd install $pkgs_cmdln_tools ; pkgin -y install $pkgs_cmdln_tools

# clamd freshclamd
for svc in dbus avahidaemon cupsd ; do
	cp /usr/pkg/share/examples/rc.d/$svc /etc/rc.d/ ;
done
mkdir -p /var/run/dbus

hash_passwd=$(pwhash ${PLAIN_PASSWD})
mkdir -p /home/packer
#DIR_MODE=0750 
useradd -m -G wheel,operator -s /bin/ksh -c 'Packer User' packer
usermod -p "${hash_passwd}" packer
chown -R packer:$(id -gn packer) /home/packer

if [ ! -z "$(sysctl -n kern.hostname | grep 0000)" ] ; then
	#last4=$(cat /etc/hostid | cut -b33-36) ;
	last4=$(sysctl -n machdep.dmi.system-uuid | cut -b33-36) ;
	init_hostname=$(hostname) ;
	NAME=$(echo ${init_hostname} | sed "s|0000|${last4}|") ;
	sed -i "/${init_hostname}/ s|${init_hostname}|${NAME}|" /etc/rc.conf ;
	sed -i "/${init_hostname}/ s|${init_hostname}|${NAME}|" /etc/hosts ;
fi

set +e ; set +u

#echo 'ntpd=YES' >> /etc/rc.conf
# Set the time correctly
#ntpd -u ntp:ntp ; ntpq -p ; sleep 3
ntpdate -v -u -b us.pool.ntp.org

pfctl -d
echo 'pf=YES' >> /etc/rc.conf
echo 'pflogd=YES' >> /etc/rc.conf
sh /root/firewall/pf/pfconf.sh config_pf allow >> /etc/pf.conf
sed -i '/icmp6 / s|icmp6 |ipv6-icmp |' /etc/pf/outallow_in_allow.rules
sed -i '/icmp6 / s|icmp6 |ipv6-icmp |' /etc/pf/outdeny_out_allow.rules
pfctl -vf /etc/pf.conf ; pfctl -s info ; sleep 5 ; pfctl -s rules -a '*'
sleep 5

#echo 'freshclamd=YES' >> /etc/rc.conf
#echo 'clamd=YES' >> /etc/rc.conf
#sh /root/baseinstall.sh check_clamav

#echo 'sshd=YES' >> /etc/rc.conf

# clamd freshclamd
for svc in dbus avahidaemon cupsd lpd ; do
	echo "${svc}=YES" >> /etc/rc.conf ;
done

#sed -i '/hosts:/ s| dns| mdns_minimal \[NOTFOUND=return\] dns mdns|' /etc/nsswitch.conf
sed -i '/hosts:/ s|files|files mdns_minimal \[NOTFOUND=return\]|' /etc/nsswitch.conf

#usermod -G cups root ; usermod -G cups packer

#sh /root/misc_config.sh cfg_printer_default $SHAREDNODE $PRINTNAME
sh /root/misc_config.sh cfg_printer_pdf \
    /usr/pkg/share/cups/model/CUPS-PDF.ppd /usr/pkg/etc/cups/cups-pdf.conf
#echo 'pass in proto udp from any to any port { mdns } keep state' >> /etc/pf/outallow_in_allow.rules
sed -i 's|domain|domain, mdns|' /etc/pf/outallow_in_allow.rules
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

#sh -c 'cat >> /usr/pkg/etc/sudoers.d/99_packer' << EOF
#Defaults:packer !requiretty
#$(id -un packer) ALL=(ALL) NOPASSWD: ALL
#EOF
#chmod 0440 /usr/pkg/etc/sudoers.d/99_packer

sh /root/misc_config.sh cfg_sshd
sh /root/misc_config.sh cfg_shell_keychain /etc/skel/.cshrc
sh /root/misc_config.sh share_nfs_data0 $SHAREDNODE

(cd /etc/skel ; mkdir -p .gnupg .ssh .pki)
cp -R /root/skel/_gnupg/* /etc/skel/.gnupg/
cp -R /root/skel/_ssh/* /etc/skel/.ssh/
cp -R /root/skel/_pki/* /etc/skel/.pki/
cp /root/skel/_gitconfig /etc/skel/.gitconfig
cp /root/skel/_hgrc /etc/skel/.hgrc

sshca_pubkey="/etc/skel/.ssh/publish_krls/sshca-id_ed25519.pub"
sshca_krl="/etc/skel/.ssh/publish_krls/krl.krl"
if [ -e $sshca_pubkey ] ; then
	echo "@cert-authority 192.168.* $(cat $sshca_pubkey)" >> \
		/etc/skel/.ssh/known_hosts ;
	cp $sshca_krl $sshca_pubkey /etc/ssh/ ;
fi
