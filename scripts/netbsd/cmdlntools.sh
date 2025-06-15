#!/bin/sh -eux

export SHAREDNODE=${1:-localhost.local} ; export PRINTNAME=${2:-printer1}
set +e

#set path = (~/bin /bin /sbin /usr/{bin,sbin,X11R7/bin,pkg/{,s}bin,games} \
#  /usr/local/{,s}bin)
export PATH=${HOME}/bin:/bin:/sbin:/usr/bin:/usr/sbin:/usr/X11R7/bin:/usr/pkg/bin:/usr/pkg/sbin:/usr/pkg/games:/usr/local/bin:/usr/local/sbin

pkgin update

#read -p "Fetch missing distribution sets? Enter 'y' to continue [yN]: " response
#if [ "y" = "${response}" ] || [ "Y" = "${response}" ] ; then
#  # fetch missing distribution sets like: xbase.tar.xz
#  # uname_m: [amd64 | arm64] ; rel: X.Y
#  uname_m=$(uname -m) ; rel=$(sysctl -n kern.osrelease) ;
#  cd /tmp ;
#  for setX in xbase ; do
#    ftp http://cdn.netbsd.org/pub/NetBSD/NetBSD-${rel}/${uname_m}/binary/sets/${setX}.tar.xz ;
#    tar -C / -xpJf ${setX}.tar.xz ;
#  done ;
#fi

. /root/scripts/distro_pkgs.ini ; echo ${pkgs_cmdln_tools}

read -p "Enter 'y' to continue [nY]: " response
#if [ "n" = "${response}" ] || [ "N" = "${response}" ] ; then
if [ -n "$(echo ${response} | grep -e '^[Nn].*')" ] ; then
  exit ;
fi
#pkgin [-d] -y install pkg0 .. pkgN # OK, skips missing
pkgin -y install ${pkgs_cmdln_tools}

#/usr/pkg/bin/dbus-uuidgen --ensure[=/var/lib/dbus/machine-id]
if [ ! -z "$(sysctl -n kern.hostname | grep 0000)" ] ; then
  #idsuffix=$(cat /etc/hostid | cut -b33-36) ;
  if [ ! "$(sysctl -n machdep.dmi.system-uuid)" = "00000000-0000-0000-0000-000000000000" ] ; then
    idsuffix=$(sysctl -n machdep.dmi.system-uuid | cut -b33-36) ;
  elif [ -e /var/lib/dbus/machine-id ] ; then
    idsuffix=$(cat /var/lib/dbus/machine-id | cut -b29-32) ;
  fi ;
  for fileX in /etc/hosts /etc/rc.conf ; do
    sed -i "/box.0000/ s|\(box.\)0000|\1${idsuffix:-0000}|g" ${fileX} ;
  done ;
  hostname $(cat /etc/hostname) ;
fi

if [ -n "$(java -version)" ] ; then
  #java_home=$(dirname $(dirname $(realpath $(which java)))) ;
  java_home=$(realpath $(which java) | sed "s:/bin/java::") ;
  #if [ -z "$(grep '^export JAVA_HOME' /etc/ksh.kshrc)" ] ; then
  if [ -z "$(grep '^export JAVA_HOME' /etc/profile.d/jdk.sh)" ] ; then
    echo 'export JAVA_HOME=${java_home}' >> /etc/profile.d/jdk.sh ;
  fi ;
  if [ -z "$(grep '^fdesc' /etc/fstab)" ] ; then
    echo 'fdesc  /dev/fd  fdescfs  rw  0  0' >> /etc/fstab ;
  fi ;
fi

#chgrp [mail | wheel] /var/mail ; chmod [g+ws,+t | 3775] /var/mail
chgrp mail /var/mail ; chmod g+ws,+t /var/mail

(cd /etc/skel ; mkdir -p .gnupg .ssh .pki)
(cd /root/init/common ; cp -a skel/_gnupg/* /etc/skel/.gnupg/ ; \
  cp -a skel/_ssh/* /etc/skel/.ssh/ ; cp -a skel/_pki/* /etc/skel/.pki/ ; \
  cp -a skel/_gitconfig.sample /etc/skel/.gitconfig ; \
  cp -a skel/_hgrc.sample /etc/skel/.hgrc)


set +e ; set +u
mkdir -p /var/run/dbus /var/db/dbus
# clamd freshclamd
for svc in dbus avahidaemon cupsd ; do
  cp -a /usr/pkg/share/examples/rc.d/${svc} /etc/rc.d/ ;
done

groupadd -g 81 dbus
useradd -c 'System message bus' -u 81 -g dbus -d '/' -s /usr/bin/false dbus

# change daily security mail output to log file
cp -an /etc/daily /etc/daily.orig
sed -i "s|\(^.*\)\(mail .*daily insecurity output.*$\)|\1#\2\n\1cat \$SECOUT > /var/log/security.out|" /etc/daily

#groupadd -g 193 cups ; usermod -G cups root
#for file1 in lp lpq lpr lprm ; do
#  if [ -e /usr/bin/${file1} ] ; then
#    mv /usr/bin/${file1} /usr/bin/${file1}.old ;
#  fi ;
#  if [ 'NetBSD' = "$(uname -s)" ] ; then
#    ln -s /usr/pkg/bin/${file1} /usr/bin/${file1} ;
#  else
#    ln -s /usr/local/bin/${file1} /usr/bin/${file1} ;
#  fi
#done

sh /root/init/common/cron/bsd/config_cron.sh

smtp_daemon=${smtp_daemon:-postfix}
# config postfix -- maildir format vice mbox
if [ -z "$(service -e | grep postfix)"] ; then
  echo postfix=YES >> /etc/rc.conf ;
fi
service postfix restart || true
# [home_mailbox=Maildir/ | mail_spool_directory=/var/mail/]
#echo "mail_spool_directory = /var/mail/" >> /etc/postfix/main.cf
postconf mail_spool_directory=/var/mail/
postfix reload
for userX in root packer vagrant ; do
  [ ! -e /var/mail/${userX}.old ] && \
    mv /var/mail/${userX} /var/mail/${userX}.old ;
done

firewall_tool=${firewall_tool:-pf}
sh /root/init/common/firewall/bsd/config_pf.sh #config_pf allow
#diff -s /etc/pf.conf /etc/pf.conf.new ; sleep 5
#(sleep 120 && /sbin/pfctl -d)& && /sbin/pfctl -e
/sbin/pfctl -e

if [ -z "$(grep -e 'domain.*mdns' /etc/pf/outallow_in_allow.rules)" ] ; then
  #echo 'pass in proto udp from any to any port { domain, mdns } keep state' >> /etc/pf/outallow_in_allow.rules ;
  if [ 'FreeBSD' = "$(uname -s)" ] ; then
    sed -i '' 's|domain|domain, mdns|g' /etc/pf/outallow_in_allow.rules ;
  else
    sed -i 's|domain|domain, mdns|g' /etc/pf/outallow_in_allow.rules ;
  fi ;
fi
/sbin/pfctl -s info ; sleep 5 #; /sbin/pfctl -s rules -a '*' ; sleep 5


set -e ; set -u
sh /root/init/common/misc_config.sh cfg_nsswitch_mdns
sh /root/init/common/misc_config.sh cfg_sudo_nopasswd /usr/pkg/etc/sudoers.d
#sh /root/init/common/misc_config.sh check_clamav
sh /root/init/common/misc_config.sh cfg_sshd
sh /root/init/common/misc_config.sh cfg_shell_keychain /etc/skel/.cshrc
sh /root/init/common/misc_config.sh cfg_shell_keychain /etc/skel/.shrc

# As sharedfolders are not in defaults ports tree, we will use NFS sharing
#services_enabled="${services_enabled} rpcbind mountd nfsd"
sh /root/init/common/misc_config.sh share_nfs_data0 ${SHAREDNODE}

#sh /root/init/common/misc_config.sh cfg_printer_pdf /usr/pkg/etc/cups \
#  /usr/pkg/share/cups/model
#sh /root/init/common/misc_config.sh cfg_printer_default ${SHAREDNODE} ${PRINTNAME}
lpstat -t || true ; sleep 5

set +e ; set +u
echo "Enable|disable services" ; sleep 3
for svc in ${services_enabled} ; do
  if [ -z "$(service -e | grep ${svc})" ] ; then
    echo ${svc}=YES >> /etc/rc.conf ;
  fi ;
done
for svc in ${services_disabled} ; do
  if [ -n "$(service -e | grep ${svc})" ] ; then
    echo ${svc}=NO >> /etc/rc.conf ;
  fi ;
done


cat << EOF | sendmail -t root
To: packer
Subject: Subject sample

Email sample
EOF
mail_cmd=$(basename $(which nail s-nail mailx | head -n1))
echo Sample email | ${mail_cmd:-mail} -r vagrant@$(hostname -s || hostname) \
  -s "Sample subject" root packer
set -e ; set -u

set +e
pkgin -y clean # #?? clean
