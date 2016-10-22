#!/bin/sh -eux

# nc -l [-p] {port} > file ## nc -w3 {host} {port} < file  # netcat xfr
# ssh user@ipaddr "sudo sh -xs - arg1 argN" < script.sh  # w/ sudo
# ssh user@ipaddr "su -m root -c 'sh -xs - arg1 argN'" < script.sh

# passwd crypted hash: [md5|sha256|sha512] - [$1|$5|$6]$...
# python -c 'import crypt,getpass ; print(crypt.crypt(getpass.getpass(), "$6$16CHARACTERSSALT"))'
# perl -e 'print crypt("password", "\$6\$16CHARACTERSSALT") . "\n"'

if command -v aria2c > /dev/null 2>&1 ; then
	FETCH_CMD=${FETCH_CMD:-aria2c} ;
fi
set +x
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

# fetch missing distribution components like: src.txz
#proc=$(uname -p) ; fbsd_ver=$(freebsd-version | sed 's|\([^-]*-[^-]*\).*|\1|')
#fetch ftp://ftp.freebsd.org/pub/FreeBSD/releases/${proc}/${fbsd_ver}/src.txz
#tar -C / -xzvf src.txz


pkg -o OSVERSION=9999999 update -f ; pkg upgrade -y
. /root/distro_pkgs.txt
pkg fetch -dy $pkgs_cmdln_tools
pkg install -y $pkgs_cmdln_tools

mkdir -p /home/packer
echo -n "${PLAIN_PASSWD}" | pw useradd packer -h 0 -m -G wheel,operator -s /bin/tcsh -d /home/packer -c "Packer User"
#echo -n "${CRYPTED_PASSWD}" | pw useradd packer -H 0 -m -G wheel,operator -s /bin/tcsh -d /home/packer -c "Packer User"
chown -R packer:$(id -gn packer) /home/packer

if [ ! -z "$(sysrc hostname | grep 0000)" ] ; then
	#last4=$(cat /etc/hostid | cut -b33-36) ;
	last4=$(sysctl -n kern.hostuuid | cut -b33-36) ;
	init_hostname=$(hostname) ;
	NAME=$(echo ${init_hostname} | sed "s|0000|${last4}|") ;
	sysrc hostname="${NAME}" ;
	sed -i '' "/${init_hostname}/ s|${init_hostname}|${NAME}|" /etc/hosts ;
fi

set +e ; set +u

#sysrc ntpd_enable="YES"
# Set the time correctly
#ntpd -u ntp:ntp ; ntpq -p ; sleep 3
ntpdate -v -u -b us.pool.ntp.org

pfctl -d
sysrc pf_enable="YES"
sysrc pflog_enable="YES"
sh /root/firewall/pf/pfconf.sh config_pf allow >> /etc/pf.conf
pfctl -vf /etc/pf.conf ; pfctl -s info ; sleep 5 ; pfctl -s rules -a '*'
sleep 5

#sysrc clamav_freshclam_enable="YES"
#sysrc clamav_clamd_enable="YES"
#sh /root/baseinstall.sh check_clamav

sysrc sshd_enable="YES"
sysrc dbus_enable="YES"
sysrc lpd_enable="NO"
sysrc cupsd_enable="YES"
sysrc devd_enable="YES"
#sysrc devfs_enable="YES"
sysrc devfs_system_ruleset="system"

sysrc avahi_daemon_enable="YES"

sh -c 'cat >> /etc/devfs.rules' << EOF
[system=10]
add path 'unlpt*' mode 0660 group cups
add path 'ulpt*' mode 0660 group cups
add path 'lpt*' mode 0660 group cups

# dmesg | grep -e ugen
#add path 'usb/X.Y.Z' mode 0660 group cups
#add path 'usb/*' mode 0660 group cups

EOF
#sed -i '' '/hosts:/ s| dns| mdns_minimal \[NOTFOUND=return\] dns mdns|' /etc/nsswitch.conf
sed -i '' '/hosts:/ s|files|files mdns_minimal \[NOTFOUND=return\]|' /etc/nsswitch.conf

cd /usr/bin
for file1 in lp lpq lpr lprm ; do
    mv $file1 $file1.old ;
    ln -s /usr/local/bin/$file1 $file1 ;
done

pw groupmod cups -m root ; pw groupmod cups -m packer

#sh /root/misc_config.sh cfg_printer_default $SHAREDNODE $PRINTNAME
sh /root/misc_config.sh cfg_printer_pdf \
    /usr/local/share/cups/model/CUPS-PDF.ppd /usr/local/etc/cups/cups-pdf.conf
#echo 'pass in proto udp from any to any port { mdns } keep state' >> /etc/pf/outallow_in_allow.rules
sed -i '' 's|domain|domain, mdns|' /etc/pf/outallow_in_allow.rules
set -e ; set -u


# Emulate the ETCSYMLINK behavior of ca_root_nss; this is for FreeBSD 10,
# where fetch(1) was massively refactored and doesn't come with
# SSL CAcerts anymore
mkdir -p /etc/ssl
ln -sf /usr/local/share/certs/ca-root-nss.crt /etc/ssl/cert.pem

# As sharedfolders are not in defaults ports tree, we will use NFS sharing
#sysrc rpcbind_enable="YES"
#sysrc nfs_server_enable="YES"
#sysrc mountd_flags="-r"

# Disable X11 because Vagrants VMs are (usually) headless
#sysrc -f /etc/make.conf WITHOUT_X11="YES"

sed -i '' "/PermitRootLogin/ s|^\(.*\)$|PermitRootLogin no|" /etc/ssh/sshd_config
sed -i '' "/^%wheel.*(ALL)\s*ALL/ s|%wheel|# %wheel|" /usr/local/etc/sudoers
sed -i '' "/^#.*%wheel.*NOPASSWD.*/ s|^#.*%wheel|%wheel|" /usr/local/etc/sudoers
if [ -z "$(grep '^%wheel ALL=(ALL) NOPASSWD: ALL' /usr/local/etc/sudoers)" ] ; then
	echo '%wheel ALL=(ALL) NOPASSWD: ALL' >> /usr/local/etc/sudoers ;
fi
sed -i '' "s|^[^#].*requiretty|# Defaults requiretty|" /usr/local/etc/sudoers

#sh -c 'cat >> /usr/local/etc/sudoers.d/99_packer' << EOF
#Defaults:packer !requiretty
#$(id -un packer) ALL=(ALL) NOPASSWD: ALL
#EOF
#chmod 0440 /usr/local/etc/sudoers.d/99_packer

sh /root/misc_config.sh cfg_sshd
sh /root/misc_config.sh cfg_shell_keychain /usr/share/skel/dot.cshrc
sysrc nfs_client_enable="YES"
sh /root/misc_config.sh share_nfs_data0 $SHAREDNODE

(cd /usr/share/skel ; mkdir -p dot.gnupg dot.ssh dot.pki)
cp -R /root/skel/_gnupg/* /usr/share/skel/dot.gnupg/
cp -R /root/skel/_ssh/* /usr/share/skel/dot.ssh/
cp -R /root/skel/_pki/* /usr/share/skel/dot.pki/
cp /root/skel/_gitconfig /usr/share/skel/dot.gitconfig
cp /root/skel/_hgrc /usr/share/skel/dot.hgrc

sshca_pubkey="/usr/share/skel/dot.ssh/publish_krls/sshca-id_ed25519.pub"
sshca_krl="/usr/share/skel/dot.ssh/publish_krls/krl.krl"
if [ -e $sshca_pubkey ] ; then
	echo "@cert-authority 192.168.* $(cat $sshca_pubkey)" >> \
		/usr/share/skel/dot.ssh/known_hosts ;
	cp $sshca_krl $sshca_pubkey /etc/ssh/ ;
fi


set +e
## freebsd/cleanup.sh
pkg clean -y
portmaster -n --clean-distfiles

# Purge files we don't need any longer
rm -rf /var/db/freebsd-update/files
mkdir -p /var/db/freebsd-update/files
rm -f /var/db/freebsd-update/*-rollback
rm -rf /var/db/freebsd-update/install.*
rm -f /*.core ; rm -rf /boot/kernel.old #; rm -rf /usr/src/*
