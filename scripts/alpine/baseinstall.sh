#!/bin/sh -eux

# nc -l [-p] {port} > file ## nc -w3 {host} {port} < file  # netcat xfr
# ssh user@ipaddr "su -c 'sh -xs - arg1 argN'" < script.sh
# ssh user@ipaddr "sudo sh -xs - arg1 argN" < script.sh  # w/ sudo

# passwd crypted hash: [md5|sha256|sha512] - [$1|$5|$6]$...
# python -c 'import crypt,getpass ; print(crypt.crypt(getpass.getpass(), "$6$16CHARACTERSSALT"))'
# perl -e 'print crypt("password", "\$6\$16CHARACTERSSALT") . "\n"'

set +x
PLAIN_PASSWD=${PLAIN_PASSWD:-abcd0123}
set -x
#CRYPTED_PASSWD=$(echo -n $PLAIN_PASSWD | python -c 'import sys,crypt ; print(crypt.crypt(sys.stdin.read(), "$6$16CHARACTERSSALT"))')

export SHAREDNODE=${1:-localhost.local} ; export PRINTNAME=${2:-printer1}

check_clamav() {
    freshclam --verbose ; sleep 3 ; freshclam --list-mirrors ; sleep 5
    wget --no-check-certificate -O /tmp/eicar.com.txt https://secure.eicar.org/eicar.com.txt
    clamscan --verbose /tmp/eicar.com.txt ; sleep 5 ; clamscan --recursive /tmp
    rm /tmp/eicar.com.txt
}

set +e
#set -e

apk update ; apk upgrade -U -a
. /root/distro_pkgs.txt
apk add $pkgs_cmdln_tools

#rc-update add sshd default

#DIR_MODE=0750 
useradd -m -g users -G wheel -s /bin/bash -c 'Packer User' packer
echo -n "packer:${PLAIN_PASSWD}" | chpasswd
#echo -n 'packer:${CRYPTED_PASSWD}' | chpasswd -e
chown -R packer:$(id -gn packer) /home/packer

service dbus start
if [ ! -z "$(grep 0000 /etc/hostname)" ] ; then
	last4=$(cat /etc/machine-id | cut -b29-32) ;
	#last4=$(cat /var/lib/dbus/machine-id | cut -b29-32) ;
	init_hostname=$(cat /etc/hostname) ;
	NAME=$(echo ${init_hostname} | sed "s|0000|${last4}|") ;
	echo "${NAME}" > /etc/hostname ;
	sed -i "/${init_hostname}/ s|${init_hostname}|${NAME}|" /etc/hosts ;
fi

set +e ; set +u
ntpd -u ntp:ntp ; ntpq -p ; sleep 3
rc-update add openntpd default

sh /root/firewall/nftables/config_nftables.sh cmds_nftables allow	# cmds | config
#ipset flush ; iptables -F ; ip6tables -F
#ipset destroy ; iptables -X ; ip6tables -X
for unit in ipset iptables ip6tables ; do
	service $unit stop ;
	rc-update del $unit default ;
done
service nftables save
rc-update add nftables default


mkdir -p /var/lib/clamav ; chown -R clamav:clamav /var/lib/clamav
touch /var/lib/clamav/clamd.sock
#sh /root/baseinstall.sh check_clamav
rc-update add freshclam default
rc-update add clamd default
set -e ; set -u


#sed -i '/hosts:/ s|files|files mdns_minimal \[NOTFOUND=return\]|' /etc/nsswitch.conf

for svc in dbus cupsd avahi-daemon ; do
    rc-update add $svc default
done

set +e
#sh /root/misc_config.sh cfg_printer_default $SHAREDNODE $PRINTNAME
sh /root/misc_config.sh cfg_printer_pdf \
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

#sh -c 'cat > /etc/sudoers.d/99_packer' << EOF
#Defaults:packer !requiretty
#$(id -un packer) ALL=(ALL) NOPASSWD: ALL
#
#EOF
#chmod 0440 /etc/sudoers.d/99_packer

sh /root/misc_config.sh cfg_sshd
sh /root/misc_config.sh cfg_shell_keychain
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


## alpine/cleanup.sh
apk -v cache clean
