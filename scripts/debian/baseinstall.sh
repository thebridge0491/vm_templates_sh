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

## debian/update.sh
arch="$(uname -r | sed 's|^.*[0-9]\{1,\}\.[0-9]\{1,\}\.[0-9]\{1,\}\(-[0-9]\{1,2\}\)-||')"
sed -i '/main.*$/ s|main.*$|main contrib non-free|' /etc/apt/sources.list


apt-get -y upgrade linux-image-$arch
apt-get -y --no-install-recommends install linux-headers-$arch #linux-headers-$(uname -r)

if [ -d /etc/init ] ; then
    # update package index on boot
    sh -c 'cat > /etc/init/refresh-apt.conf' << EOF ;
description "update package index"
start on networking
task
exec /usr/bin/apt-get update
EOF
fi

apt-get update ; apt-get -y upgrade
. /root/distro_pkgs.txt
apt-get -y --no-install-recommends install $pkgs_cmdln_tools

set +e

DIR_MODE=0750 useradd -m -G operator,sudo -s /bin/bash -c 'Packer User' packer
echo -n "packer:${PLAIN_PASSWD}" | chpasswd
#echo -n "packer:${CRYPTED_PASSWD}" | chpasswd -e
chown -R packer:$(id -gn packer) /home/packer

if [ ! -z "$(grep 0000 /etc/hostname)" ] ; then
	#last4=$(cat /etc/machine-id | cut -b29-32) ;
	last4=$(cat /var/lib/dbus/machine-id | cut -b29-32) ;
	init_hostname=$(cat /etc/hostname) ;
	NAME=$(echo ${init_hostname} | sed "s|0000|${last4}|") ;
	echo "${NAME}" > /etc/hostname ;
	sed -i "/${init_hostname}/ s|${init_hostname}|${NAME}|" /etc/hosts ;
fi

set +e ; set +u
tasksel --list-tasks ; sleep 5

ntpd -u ntp:ntp ; ntpq -p ; sleep 3
systemctl enable ntp.service

sh /root/firewall/ufw/config_ufw.sh cmds_ufw allow
systemctl enable ufw.service

#sh /root/baseinstall.sh check_clamav
systemctl enable clamav-freshclam.service


#sh /root/misc_config.sh cfg_printer_default $SHAREDNODE $PRINTNAME
sh /root/misc_config.sh cfg_printer_pdf \
    /usr/share/ppd/cups-pdf/CUPS-PDF.ppd /etc/cups/cups-pdf.conf
#ufw allow in svc MDNS
set -e ; set -u

sed -i "/^%sudo.*(ALL)\s*ALL/ s|%sudo|# %sudo|" /etc/sudoers
#sed -i "/^#.*%sudo.*NOPASSWD.*/ s|^#.*%sudo|%sudo|" /etc/sudoers
if [ -z "$(grep '^%sudo ALL=(ALL) NOPASSWD: ALL' /etc/sudoers)" ] ; then
	echo '%sudo ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers ;
fi
sed -i "s|^[^#].*requiretty|# Defaults requiretty|" /etc/sudoers

#sh -c 'cat >> /etc/sudoers.d/99_packer' << EOF
#Defaults:packer !requiretty
#$(id -un packer) ALL=(ALL) NOPASSWD: ALL
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

usermod -aG users packer

## debian/sudoers.sh
# Only add the secure path line if it is not already present
grep -q 'secure_path' /etc/sudoers \
  || sed -i '/Defaults\s\+env_reset/a Defaults\tsecure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"' /etc/sudoers


## debian/cleanup.sh
apt-get -y clean

