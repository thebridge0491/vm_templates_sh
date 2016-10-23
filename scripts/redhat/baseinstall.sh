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

yum -y install epel-release ; yum -y check-update ; yum -y upgrade
. /root/distro_pkgs.txt ; yum -y --setopt=requires_policy=strong --setopt=group_package_type=mandatory install $pkgs_cmdln_tools
yum -y groups mark convert

DIR_MODE=0750 useradd -m -G wheel -s /bin/bash -c 'Packer User' packer
echo -n "packer:${PLAIN_PASSWD}" | chpasswd
#echo -n "packer:${CRYPTED_PASSWD}" | chpasswd -e
chown -R packer:$(id -gn packer) /home/packer

if [ ! -z "$(grep 0000 /etc/hostname)" ] ; then
	last4=$(cat /etc/machine-id | cut -b29-32) ;
	#last4=$(cat /var/lib/dbus/machine-id | cut -b29-32) ;
	init_hostname=$(cat /etc/hostname) ;
	NAME=$(echo ${init_hostname} | sed "s|0000|${last4}|") ;
	echo "${NAME}" > /etc/hostname ;
	sed -i "/${init_hostname}/ s|${init_hostname}|${NAME}|" /etc/hosts ;
	sed -i "/${init_hostname}/ s|${init_hostname}|${NAME}|" \
		/etc/sysconfig/network ;
fi

set +e ; set +u
yum group list -v hidden ; sleep 5
yum -y --setopt=requires_policy=strong --setopt=group_package_type=mandatory group install base

ntpd -u ntp:ntp ; ntpq -p ; sleep 3
systemctl enable ntpd.service

sh /root/firewall/firewalld/config_firewalld.sh cmds_firewalld allow
systemctl unmask firewalld.service ; systemctl enable firewalld.service

sed -i 's|^Example|#Example|' /etc/freshclam.conf
sed -i 's|^Example|#Example|' /etc/clamd.d/scan.conf
sed -i 's|^#\s*LocalSocket|LocalSocket|' /etc/clamd.d/scan.conf
#sh /root/baseinstall.sh check_clamav
systemctl enable clamd@scan.service


#sh /root/misc_config.sh cfg_printer_default $SHAREDNODE $PRINTNAME
sh /root/misc_config.sh cfg_printer_pdf \
    /usr/share/cups/model/CUPS-PDF.ppd /etc/cups/cups-pdf.conf
firewall-cmd --zone=public --permanent --add-service=mdns
set -e ; set -u

sed -i "/^%wheel.*(ALL)\s*ALL/ s|%sudo|# %sudo|" /etc/sudoers
#sed -i "/^#.*%wheel.*NOPASSWD.*/ s|^#.*%wheel|%wheel|" /etc/sudoers
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
#sh /root/misc_config.sh cfg_shell_keychain
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

usermod -aG users packer


## redhat/cleanup.sh
distro="$(rpm -qf --queryformat '%{NAME}' /etc/redhat-release | cut -f 1 -d '-')" 

# Remove development and kernel source packages
#yum -y remove gcc cpp kernel-devel kernel-headers perl

if [ "$distro" != 'redhat' ] ; then
  yum -y clean all ;
fi
