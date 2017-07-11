#!/bin/sh -eux

# nc -l [-p] {port} > file ## nc -w3 {host} {port} < file  # netcat xfr
# ssh user@ipaddr "sudo sh -xs - arg1 argN" < script.sh  # w/ sudo
# ssh user@ipaddr "su -m root -c 'sh -xs - arg1 argN'" < script.sh

# passwd crypted hash: [md5|sha256|sha512] - [$1|$5|$6]$...
# python -c 'import crypt,getpass ; print(crypt.crypt(getpass.getpass(), "$6$16CHARACTERSSALT"))'
# perl -e 'print crypt("password", "\$6\$16CHARACTERSSALT") . "\n"'

set +x
export sed_inplace="sed -i"
PLAIN_PASSWD=${PLAIN_PASSWD:-abcd0123}
set -x
#CRYPTED_PASSWD=$(echo -n $PLAIN_PASSWD | python -c 'import sys,crypt ; print(crypt.crypt(sys.stdin.read(), "$6$16CHARACTERSSALT"))')

export SHAREDNODE=${1:-localhost.local} ; export PRINTNAME=${2:-printer1}

check_clamav() {
    freshclam --verbose ; sleep 3 ; freshclam --list-mirrors ; sleep 5
    fetch --no-verify-peer -o /tmp/eicar.com.txt https://secure.eicar.org/eicar.com.txt
    clamscan --verbose /tmp/eicar.com.txt ; sleep 5 ; clamscan --recursive /tmp
    rm /tmp/eicar.com.txt
}

set +e

# fetch missing distribution sets like: xbase59.tgz
#arch=$(arch -s) ; rel=$(sysctl -n kern.osrelease)
#ftp http://cdn.openbsd.org/pub/OpenBSD/${rel}/${arch}/xbase59.tgz
#tar -C / -xpzf xbase59.tgz


pkg_add -u #; pkg_add -ziU mupdf
. /root/distro_pkgs.txt
pkg_add -ziU -n $pkgs_cmdln_tools ; pkg_add -ziU $pkgs_cmdln_tools

mkdir -p /home/packer
#DIR_MODE=0750 
useradd -m -G wheel,operator -s /bin/ksh -c 'Packer User' packer
usermod -p "$(echo -n ${PLAIN_PASSWD} | encrypt)" packer
chown -R packer:$(id -gn packer) /home/packer

if [ ! -z "$(grep 0000 /etc/myname)" ] ; then
	#last4=$(cat /etc/hostid | cut -b33-36) ;
	last4=$(sysctl -n hw.uuid | cut -b33-36) ;
	init_hostname=$(hostname) ;
	NAME=$(echo ${init_hostname} | sed "s|0000|${last4}|") ;
	echo "${NAME}" > /etc/myname ;
	sed -i "/${init_hostname}/ s|${init_hostname}|${NAME}|" /etc/hosts ;
fi

set +e ; set +u

#rcctl enable ntpd
# Set the time correctly
#ntpd -u ntp:ntp ; ntpq -p ; sleep 3
ntpdate -v -u -b us.pool.ntp.org

pfctl -d
rcctl enable pf
rcctl enable pflogd
sh /root/firewall/pf/pfconf.sh config_pf allow >> /etc/pf.conf
pfctl -vf /etc/pf.conf ; pfctl -s info ; sleep 5 ; pfctl -s rules -a '*'
sleep 5

#rcctl enable freshclam
#rcctl enable clamd
#sh /root/baseinstall.sh check_clamav

rcctl enable sshd
rcctl enable messagebus
rcctl enable lpd
rcctl enable cupsd
rcctl enable cups_browsed

rcctl enable avahi_daemon

#sed -i '/hosts:/ s| dns| mdns_minimal \[NOTFOUND=return\] dns mdns|' /etc/nsswitch.conf
sed -i '/hosts:/ s|files|files mdns_minimal \[NOTFOUND=return\]|' /etc/nsswitch.conf

#usermod -G cups root ; usermod -G cups packer

#sh /root/misc_config.sh cfg_printer_default $SHAREDNODE $PRINTNAME
sh /root/misc_config.sh cfg_printer_pdf \
    /usr/local/share/cups/model/CUPS-PDF_opt.ppd /etc/cups/cups-pdf.conf
#echo 'pass in proto udp from any to any port { mdns } keep state' >> /etc/pf/outallow_in_allow.rules
sed -i 's|domain|domain, mdns|' /etc/pf/outallow_in_allow.rules
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

#sh -c 'cat >> /etc/sudoers.d/99_packer' << EOF
#Defaults:packer !requiretty
#$(id -un packer) ALL=(ALL) NOPASSWD: ALL
#EOF
#chmod 0440 /etc/sudoers.d/99_packer

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
