#!/bin/sh -eux

export SHAREDNODE=${1:-localhost.local} ; export PRINTNAME=${2:-printer1}
set +e

. /root/scripts/distro_pkgs.ini

install_pkgs() {
  snapshot_name=pre_cmdlntools-$(date -u "+%Y%m%d") \
    sh $(dirname ${0})/upgradepkgs.sh snapshot

  dnf --setopt=install_weak_deps=False config-manager --save
  dnf config-manager --dump | grep -we install_weak_deps

  dnf -y install epel-release ; dnf -y check-update

  echo ${pkgs_cmdln_tools}

  read -p "Enter 'y' to continue [nY]: " response
  #if [ "n" = "${response}" ] || [ "N" = "${response}" ] ; then
  if [ -n "$(echo ${response} | grep -e '^[Nn].*')" ] ; then
    exit ;
  fi
  #dnf -C --skip-broken [--downloadonly] -y install pkg0 .. pkgN # OK, skips missing
  dnf -C --skip-broken -y install ${pkgs_cmdln_tools}
  dnf -C -y groups mark convert
}

config_sys() {
  #dbus-uuidgen --ensure[=/etc/machine-id]
  #systemd-machine-id-setup --commit
  if [ ! -z "$(grep 0000 /etc/hostname)" ] ; then
    idsuffix=$(cat /etc/machine-id | cut -b29-32) ;
    #idsuffix=$(cat /var/lib/dbus/machine-id | cut -b29-32) ;
    for fileX in /etc/hosts /etc/hostname /etc/sysconfig/network ; do
      sed -i "/box.0000/ s|\(box.\)0000|\1${idsuffix:-0000}|g" ${fileX} ;
    done ;
    hostname -F /etc/hostname || hostname $(cat /etc/hostname) ;
  fi

  if [ -n "$(java -version)" ] ; then
    #java_home=$(dirname $(dirname $(realpath $(which java)))) ;
    java_home=$(realpath $(which java) | sed "s:/bin/java::") ;
    #if [ -z "$(grep '^export JAVA_HOME' /etc/bash.bashrc)" ] ; then
    if [ -z "$(grep '^export JAVA_HOME' /etc/profile.d/jdk.sh)" ] ; then
      echo 'export JAVA_HOME=${java_home}' >> /etc/profile.d/jdk.sh ;
    fi ;
    chmod +x /etc/profile.d/jdk.sh ;
    #mkdir -p ${java_home} ;
    #java_version=$(java -version | head -n1 | sed 's|.*"\([0-9]*\.[0-9*]\)".*|\1|') ;
    #if [ -z "$(grep '^JAVA_VERSION' ${java_home}/release)" ] ; then
    #  echo JAVA_VERSION="${java_version}" >> ${java_home}/release ;
    #fi ;
  fi
  #update-alternatives --get-selections
  #update-alternatives --config [java | javac | jar | javadoc | javap | jdb | keytool]

  #chgrp [mail | postfix] /var/mail ; chmod [g+ws,+t | 3775] /var/mail
  chgrp mail /var/mail ; chmod 3775 /var/mail

  (cd /etc/skel ; mkdir -p .gnupg .ssh .pki)
  (cd /root/init/common ; cp -a skel/_gnupg/* /etc/skel/.gnupg/ ; \
    cp -a skel/_ssh/* /etc/skel/.ssh/ ; cp -a skel/_pki/* /etc/skel/.pki/ ; \
    cp -a skel/_gitconfig.sample /etc/skel/.gitconfig ; \
    cp -a skel/_hgrc.sample /etc/skel/.hgrc)

  set +e ; set +u
  #mkdir -p /var/lib/clamav ; chown -R clamav:clamav /var/lib/clamav
  #touch /var/lib/clamav/clamd.sock

  #for fileX in /etc/freshclam.conf /etc/clam.d/scan.conf ; do
  #  sed -i 's|^Example|#Example|' ${fileX} ;
  #done
  #sed -i 's|^#\s*LocalSocket|LocalSocket|' /etc/clamd.d/scan.conf

  # Only add the secure path line if it is not already present
  #grep -q 'secure_path' /etc/sudoers \
  #  || sed -i '/Defaults\s\+env_reset/a Defaults\tsecure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"' /etc/sudoers

  if [ ! "$(dmesg | grep -iE 'kvm|qemu|hypervisor')" ] ; then
    if [ -n "$(lspci | grep -ie wireless)" ] ; then
      psk=`wpa_passphrase ${SSID:-HOME24-WIFI} ${passphrase:-abcd0123} | sed -n 's|^[[:space:]]*psk=\(.*\)|\1|p'` ;
      nmcli device wifi list ; sleep 3 ;
      nmcli device wifi connect ${SSID:-HOME24-WIFI} password ${psk} ;
      #nmcli device connection up ${SSID:-HOME24-WIFI}
      # see /etc/NetworkManager/system-connections/*
    fi ;
  fi

  sh /root/init/common/cron/linux/config_cron.sh

  smtp_daemon=${smtp_daemon:-postfix}
  # config postfix -- maildir format vice mbox
  systemctl enable postfix || true ; systemctl restart postfix || true
  # [home_mailbox=Maildir/ | mail_spool_directory=/var/spool/mail/]
  #echo "mail_spool_directory = /var/spool/mail/" >> /etc/postfix/main.cf
  postconf mail_spool_directory=/var/spool/mail/
  postfix reload
  for userX in root packer vagrant ; do
    [ ! -e /var/mail/${userX}.old ] && \
      mv /var/mail/${userX} /var/mail/${userX}.old ;
  done
  #mkdir -p -m 0700 /var/mail/postfix ; chown postfix:postfix /var/mail/postfix
  #(cd /var/mail ; ln -s postfix root)

  firewall_tool=${firewall_tool:-firewalld}
  #sh /root/init/common/firewall/linux/config_nftables.sh #config_nftables allow
  ##diff -s /etc/nftables.conf /etc/nftables.conf.new
  #(sleep 120 && nft flush ruleset)& \
  #  nft -f /etc/nftables.conf
  sh /root/init/common/firewall/linux/config_firewalld.sh #cmds_firewalld allow
  (sleep 120 && firewall-offline-cmd --disabled)& \
    (firewall-cmd --reload ; firewall-offline-cmd --enabled)

  #if [ -z "$(grep -e 'domain.*mdns' /etc/nftables.conf /etc/nftables/out*_nftables.conf)" ] ; then
  #  #nft add rule inet filter in_allow udp port { domain, mdns } accept ;
  #  sed -i 's|domain|domain, mdns|g' /etc/nftables.conf \
  #    /etc/nftables/out*_nftables.conf ;
  #fi
  #nft list tables ; sleep 5 ; nft list ruleset ; sleep 5
  if [ $(firewall-cmd --zone=public --query-service=mdns) ] ; then
    #yast firewall services add zone=EXT service=service:avahi ; # openSUSE
    firewall-cmd --permanent --zone=public --add-service=mdns ;
  fi
  firewall-cmd --get-active-zones ; sleep 5
  #ipset list ; sleep 5
  firewall-cmd --state ; sleep 5 ; firewall-cmd --zone=public --list-all ; sleep 5

  set -e ; set -u
  sh /root/init/common/misc_config.sh cfg_nsswitch_mdns
  sh /root/init/common/misc_config.sh cfg_sudo_nopasswd /etc/sudoers.d
  sh /root/init/common/misc_config.sh cfg_inputrc_histsearch
  #sh /root/init/common/misc_config.sh check_clamav
  sh /root/init/common/misc_config.sh cfg_sshd
  sh /root/init/common/misc_config.sh cfg_shell_keychain
  sh /root/init/common/misc_config.sh share_nfs_data0 ${SHAREDNODE}
  #sh /root/init/common/misc_config.sh cfg_printer_pdf
  #sh /root/init/common/misc_config.sh cfg_printer_default ${SHAREDNODE} ${PRINTNAME}
  lpstat -t || true ; sleep 5
  cat << EOF | sendmail -t root
To: packer
Subject: Subject sample

Email sample
EOF
  mail_cmd=$(basename $(which nail s-nail mailx | head -n1))
  echo Sample email | ${mail_cmd:-mail} -r vagrant@$(hostname -s || hostname) \
    -s "Sample subject" root packer
}

toggle_svcs() {
  set +e ; set +u
  echo "Enable|disable services" ; sleep 3
  for svc in ${services_enabled} ; do
    systemctl unmask ${svc} ; systemctl enable ${svc} ;
  done
  for svc in ${services_disabled} ; do
    systemctl disable ${svc} ; systemctl mask ${svc} ;
  done

  set +e
  ## scripts/cleanup.sh
  distro="$(rpm -qf --queryformat '%{NAME}' /etc/redhat-release | cut -f 1 -d '-')"

  # Remove development and kernel source packages
  #dnf -y remove gcc cpp kernel-devel kernel-headers perl

  if [ "${distro}" != 'redhat' ] ; then
    dnf -y clean all ;
  fi
}

run_all() {
  install_pkgs
  config_sys
  toggle_svcs
}

#----------------------------------------
${@:-run_all}
