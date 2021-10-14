#!/bin/sh -eux

if command -v aria2c > /dev/null ; then
	FETCH_CMD=${FETCH_CMD:-aria2c} ;
fi

export SED_INPLACE="sed -i ''"
export SHAREDNODE=${1:-localhost.local} ; export PRINTNAME=${2:-printer1}

set +e

# fetch missing distribution components like: src.txz
#proc=$(uname -p) ; fbsd_ver=$(freebsd-version | sed 's|\([^-]*-[^-]*\).*|\1|')
#fetch ftp://ftp.freebsd.org/pub/FreeBSD/releases/${proc}/${fbsd_ver}/src.txz
#tar -C / -xzvf src.txz


. /root/init/freebsd/distro_pkgs.ini
pkg update
for pkgX in $pkgs_cmdln_tools ; do
	pkg fetch -Udy $pkgX ;
done
for pkgX in $pkgs_cmdln_tools ; do
	pkg install -Uy $pkgX ;
done


if [ -z "$(grep '^setenv JAVA_HOME' /etc/csh.cshrc)" ] ; then
  echo "setenv JAVA_HOME ${default_java_home}" >> /etc/csh.cshrc ;
fi
if [ -z "$(grep '^fdesc' /etc/fstab)" ] ; then
  echo 'fdesc  /dev/fd  fdescfs  rw  0  0' >> /etc/fstab ;
fi

#uuidgen > /etc/hostid ; reboot
if [ "$(hostname | grep -e 'box.0000')" ] ; then
	last4=$(sysctl -n kern.hostuuid | cut -b33-36) ; # cat /etc/hostid
	for fileX in /etc/hosts /etc/rc.conf ; do
	  sed -i '' "/box.0000/ s|\(box.\)0000|\1${last4}|g" $fileX ;
	done ;
	hostname $(sysrc -n hostname) ;
fi


set +e ; set +u
#sysrc sshd_enable="YES" ; sysrc ntpd_enable="YES"
sysrc pf_enable="YES" ; sysrc pflog_enable="YES"
#sysrc clamav_freshclam_enable="YES" ; sysrc clamav_clamd_enable="YES"

# Set the time correctly
#ntpd -u ntp:ntp ; ntpq -p ; sleep 3
ntpdate -v -u -b us.pool.ntp.org

pfctl -d
sh /root/init/common/bsd/firewall/pf/pfconf.sh config_pf allow > /etc/pf.conf.new
if [ ! -e /etc/pf.conf ] ; then cp /etc/pf.conf.new /etc/pf.conf ; fi
pfctl -vf /etc/pf.conf ; pfctl -s info ; sleep 5 ; pfctl -s rules -a '*'
sleep 5

#sh /root/init/common/misc_config.sh check_clamav


sysrc devfs_system_ruleset="devfsrules_system"
sysrc devd_enable="YES"
sysrc dbus_enable="YES"
sysrc avahi_daemon_enable="YES"

#sed -i '' '/hosts:/ s|files dns|files mdns_minimal \[NOTFOUND=return\] dns mdns|' /etc/nsswitch.conf
sed -i '' '/hosts:/ s|files dns|files mdns_minimal \[NOTFOUND=return\] dns|' /etc/nsswitch.conf
#echo 'pass in proto udp from any to any port { mdns } keep state' >> /etc/pf/outallow_in_allow.rules
sed -i '' 's|domain|domain, mdns|g' /etc/pf/outallow_in_allow.rules


# Emulate the ETCSYMLINK behavior of ca_root_nss; this is for FreeBSD 10,
# where fetch(1) was massively refactored and doesn't come with
# SSL CAcerts anymore
#mkdir -p /etc/ssl
#ln -sf /usr/local/share/certs/ca-root-nss.crt /etc/ssl/cert.pem

(cd /usr/share/skel ; mkdir -p dot.gnupg dot.pki dot.ssh)
cp -R /root/init/common/skel/_gnupg/* /usr/share/skel/dot.gnupg/
cp -R /root/init/common/skel/_pki/* /usr/share/skel/dot.pki/
cp -R /root/init/common/skel/_ssh/* /usr/share/skel/dot.ssh/
cp /root/init/common/skel/_gitconfig /usr/share/skel/dot.gitconfig
cp /root/init/common/skel/_hgrc /usr/share/skel/dot.hgrc

sed -i '' "/PermitRootLogin/ s|^\(.*\)$|PermitRootLogin no|" /etc/ssh/sshd_config
if [ "$(grep '^.*%wheel.*ALL.*NOPASSWD.*' /usr/local/etc/sudoers)" ] ; then
  sed -i '' "s|^.*%wheel.*ALL.*NOPASSWD.*|%wheel ALL=(ALL) NOPASSWD: ALL|" /usr/local/etc/sudoers ;
else
	echo '%wheel ALL=(ALL) NOPASSWD: ALL' >> /usr/local/etc/sudoers ;
fi
sed -i '' "s|^[^#].*requiretty|# Defaults requiretty|" /usr/local/etc/sudoers

sh /root/init/common/misc_config.sh cfg_sshd /usr/share/skel/dot.ssh
sh /root/init/common/misc_config.sh cfg_shell_keychain /usr/share/skel/dot.cshrc


# As sharedfolders are not in defaults ports tree, we will use NFS sharing
#sysrc rpcbind_enable="YES"
#sysrc nfs_server_enable="YES"
#sysrc mountd_flags="-r"

sysrc nfs_client_enable="YES"
sh /root/init/common/misc_config.sh share_nfs_data0 $SHAREDNODE


# Disable X11 because Vagrants VMs are (usually) headless
#sysrc -f /etc/make.conf WITHOUT_X11="YES"


sysrc lpd_enable="NO"
sysrc cupsd_enable="YES"

pw groupadd -n cups -g 193
pw groupmod cups -m root

if [ ! "$(grep -e '[devfsrules_system=10]' /etc/devfs.rules)" ] ; then
    cat <<-EOF >> /etc/devfs.rules ;
[devfsrules_system=10]
add path 'unlpt*' group cups mode 0660
add path 'ulpt*' group cups mode 0660
add path 'lpt*' group cups mode 0660

#NOTE, find USB device correspond to printer: dmesg | grep -e ugen
#add path 'usb/X.Y.Z' group cups mode 0660
EOF
fi

cd /usr/bin
for file1 in lp lpq lpr lprm ; do
    if [ -e $file ] ; then
      mv $file1 $file1.old ;
    fi ;
    ln -s /usr/local/bin/$file1 $file1 ;
done

#sh /root/init/common/misc_config.sh cfg_printer_pdf /usr/local/etc/cups \
#    /usr/local/share/cups/model
##sh /root/init/common/misc_config.sh cfg_printer_default $SHAREDNODE $PRINTNAME
lpstat -t ; sleep 5
set -e ; set -u


set +e
## scripts/cleanup.sh
pkg clean -y
portmaster -n --clean-distfiles

# Purge files we don't need any longer
rm -rf /var/db/freebsd-update/files
mkdir -p /var/db/freebsd-update/files
rm -f /var/db/freebsd-update/*-rollback
rm -rf /var/db/freebsd-update/install.*
rm -f /*.core ; rm -rf /boot/kernel.old #; rm -rf /usr/src/*
