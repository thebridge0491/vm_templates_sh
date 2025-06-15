#!/bin/sh -eux

export SHAREDNODE=${1:-localhost.local} ; export PRINTNAME=${2:-printer1}
set +e

#read -p "Fetch missing distribution sets? Enter 'y' to continue [yN]: " response
#if [ "y" = "${response}" ] || [ "Y" = "${response}" ] ; then
#  # fetch missing distribution sets like: xbase*.tgz
#  # arch_s: [amd64 | arm64] ; rel: X.Y
#  arch_s=$(arch -s) ; rel=$(sysctl -n kern.osrelease) ;
#  setVer=$(sysctl -n kern.osrelease | tr '.' '\0') ;
#  cd /tmp
#  for setX in xbase ; do
#    ftp http://cdn.openbsd.org/pub/OpenBSD/${rel}/${arch_s}/${setX}${setVer}.tgz ;
#    tar -C / -xpzf ${setX}${setVer}.tgz ;
#  done ;
#
#  sysmerge ;
#fi

. /root/scripts/distro_pkgs.ini ; echo ${pkgs_cmdln_tools}

read -p "Enter 'y' to continue [nY]: " response
#if [ "n" = "${response}" ] || [ "N" = "${response}" ] ; then
if [ -n "$(echo ${response} | grep -e '^[Nn].*')" ] ; then
  exit ;
fi
#pkg_add [-n] -ziU pkg0-- .. pkgN-- # OK, skips missing
pkg_add -ziU ${pkgs_cmdln_tools}

#/usr/local/bin/dbus-uuidgen --ensure[=/etc/machine-id]
if [ ! -z "$(grep 0000 /etc/myname)" ] ; then
  #idsuffix=$(cat /etc/hostid | cut -b33-36) ;
  if [ -n "$(sysctl -n hw.uuid)" ] ; then
    idsuffix=$(sysctl -n hw.uuid | cut -b33-36) ;
  elif [ -e /etc/machine-id ] ; then
    idsuffix=$(cat /etc/machine-id | cut -b29-32) ;
  fi ;
  for fileX in /etc/hosts /etc/myname ; do
    sed -i "/box.0000/ s|\(box.\)0000|\1${idsuffix:-0000}|g" ${fileX} ;
  done ;
  hostname $(cat /etc/myname) ;
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

#                      chmod [g+ws,+t | 3775] /var/mail
#chgrp [mail | wheel] /var/mail ; chmod [g+ws,+t | 3775] /var/mail
chgrp mail /var/mail ; chmod g+ws,+t /var/mail

(cd /etc/skel ; mkdir -p .gnupg .ssh .pki)
(cd /root/init/common ; cp -a skel/_gnupg/* /etc/skel/.gnupg/ ; \
  cp -a skel/_ssh/* /etc/skel/.ssh/ ; cp -a skel/_pki/* /etc/skel/.pki/ ; \
  cp -a skel/_gitconfig.sample /etc/skel/.gitconfig ; \
  cp -a skel/_hgrc.sample /etc/skel/.hgrc)


set +e ; set +u
# disable mail output from /etc/{daily,weekly,monthly} scripts
for periodX in daily weekly monthly ; do
  cp -an /etc${periodX} /etc/${periodX}.orig ;
done
sed -i "/^[^#].*mail .*daily insecurity output.*$/ s|^|#|" /etc/daily
sed -i "s|\(^[^#].*\)mail .*daily output.*$|\1cat > /tmp/daily.out ; mv /tmp/daily.out \$MAINOUT|" /etc/daily
sed -i "/^[^#].*mail .*weekly output.*$/ s|^|#|" /etc/weekly
sed -i "/^[^#].*mail .*monthly output.*$/ s|^|#|" /etc/monthly

if [ -z "$(grep -e 'dbus-uuidgen --ensure' /etc/rc.local)" ] ; then
  #echo /usr/local/bin/dbus-uuidgen --ensure=/etc/machine-id >> /etc/rc.local ;
  echo /usr/local/bin/dbus-uuidgen --ensure >> /etc/rc.local ;
  chmod +x /etc/rc.local ;
fi

ifdev=$(ifconfig | grep '^[a-z]' | grep -ve lo0 | cut -d: -f1 | head -n1)
# /etc/rc.conf.local: mdnsd_flags=vio0
rcctl set mdnsd flags ${ifdev}
if [ -z "$(grep -e 'mdnsctl publish' /etc/rc.local)" ] ; then
  echo "/usr/local/bin/mdnsctl publish \$(hostname -s || hostname) ssh tcp 22 \"\" &" \
    >> /etc/rc.local ;
  chmod +x /etc/rc.local ;
fi

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

smtp_daemon=${smtp_daemon:-smtpd}
# smtpd.conf location varies:
#  /etc/mail/smtpd.conf: OpenBSD, Alpine Linux
#  /etc/smtpd/smtpd.conf: Void Linux, Arch Linux
#  /etc/smtpd.conf: Debian
found_smtpdconf=$(find /etc -name smtpd.conf | head -n1)
found_smtpdconf=${found_smtpdconf:-/etc/mail/smtpd.conf}
# config [open]smtpd -- maildir format vice mbox
rcctl enable ${smtp_daemon} || true ; rcctl restart ${smtp_daemon} || true
sh /root/init/common/smtp/bsd/config_opensmtpd.sh
if [ -n "$(grep 'local ! rcpt-to' ${found_smtpdconf})" ] ; then
  for userX in packer vagrant ; do
    [ ! -e /var/mail/${userX}.old ] && \
      mv /var/mail/${userX} /var/mail/${userX}.old ;
  done ;
  if [ ! "Linux" = "$(uname -s)" ] ; then
    mkdir -p /var/mail/packer ; chown packer:wheel /var/mail/packer ;
  else
    mkdir -p /var/mail/packer/{cur,new,tmp} ;
    chown -R packer:mail /var/mail/packer ;
  fi ;
fi

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
sh /root/init/common/misc_config.sh cfg_sudo_nopasswd /etc/sudoers.d
#sh /root/init/common/misc_config.sh check_clamav
sh /root/init/common/misc_config.sh cfg_sshd
sh /root/init/common/misc_config.sh cfg_shell_keychain /etc/skel/.cshrc
sh /root/init/common/misc_config.sh cfg_shell_keychain /etc/skel/.shrc

# As sharedfolders are not in defaults ports tree, we will use NFS sharing
#services_enabled="${services_enabled} rpcbind nfsd mountd"
sh /root/init/common/misc_config.sh share_nfs_data0 ${SHAREDNODE}

#sh /root/init/common/misc_config.sh cfg_printer_pdf /etc/cups \
#  /usr/local/share/cups/model
#sh /root/init/common/misc_config.sh cfg_printer_default ${SHAREDNODE} ${PRINTNAME}
lpstat -t || true ; sleep 5

set +e ; set +u
echo "Enable|disable services" ; sleep 3
for svc in ${services_enabled} ; do
  rcctl enable ${svc} ;
done
for svc in ${services_disabled} ; do
  rcctl disable ${svc} ;
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
# #?? clean
