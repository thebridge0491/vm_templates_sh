#!/bin/sh

#[aria2c --check-certificate=false | fetch --no-verify-peer | \
#  FTPSSLNOVERIFY=1 ftp [-S dont] | wget -N --no-check-certificate | \
#  curl -kOL]
#aria2c --check-certificate=false <url_prefix>/script.sh

#========================================================================#
if [ 'FreeBSD' = "$(uname -s)" ] ; then
  sed_inplace=${sed_inplace:-"sed -i ''"} ;
else
  sed_inplace=${sed_inplace:-"sed -i"} ;
fi

cfg_nsswitch_mdns() { # requires sudo/root access
  if [ -e /etc/nsswitch.conf ] ; then
    if [ 'OpenBSD' = "$(uname -s)" ] ; then
      local MOD_LINENO=0 ;
      cp -an /etc/nsswitch.conf /etc/nsswitch.conf.orig ;
      ymd=$(date -r `stat -f %m /etc/nsswitch.conf` +%Y%m%d) ;
      if [ -z "$(grep '#(old ${ymd}) hosts:' /etc/nsswitch.conf)" ] ; then
        ${sed_inplace} "/^hosts:/ s|hosts:|#(old ${ymd}) hosts:|" /etc/nsswitch.conf ;
        MOD_LINENO=$(grep -n "#(old ${ymd}) hosts:" /etc/nsswitch.conf | cut -d: -f1) ;
        #${sed_inplace} "${MOD_LINENO}a\
    #hosts:\t\tfiles mdns_minimal \[NOTFOUND=return\] dns" /etc/nsswitch.conf ;
        awk "NR==$(expr ${MOD_LINENO} + 1){print \"hosts:\t\tfiles mdns_minimal \[NOTFOUND=return\] dns\"}1" \
          /etc/nsswitch.conf > /etc/nsswitch.conf.new ;
        mv /etc/nsswitch.conf.new /etc/nsswitch.conf ;
      fi ;
    elif [ 'FreeBSD' = "$(uname -s)" ] || [ 'NetBSD' = "$(uname -s)" ] ; then
      ymd=$(date -r `stat -f %m /etc/nsswitch.conf` +%Y%m%d) ;
      if [ -z "$(grep '#(old ${ymd}) hosts:' /etc/nsswitch.conf)" ] ; then
        ${sed_inplace} "/^hosts:/ s|hosts:|#(old ${ymd}) hosts:|" /etc/nsswitch.conf ;
        ${sed_inplace} "s|^#(old ${ymd}) hosts:.*$|&\nhosts:\t\tfiles mdns_minimal \[NOTFOUND=return\] dns|" /etc/nsswitch.conf ;
      fi ;
    elif [ 'Linux' = "$(uname -s)" ] ; then
      ymd=$(date -d @`stat -c %Y /etc/nsswitch.conf` +%Y%m%d) ;
      if [ -z "$(grep '#(old ${ymd}) hosts:' /etc/nsswitch.conf)" ] ; then
        ${sed_inplace} "/^hosts:/ s|hosts:|#(old ${ymd}) hosts:|" /etc/nsswitch.conf ;
        ${sed_inplace} "/^#(old ${ymd}) hosts:/a\
hosts:\t\tfiles mdns_minimal \[NOTFOUND=return\] dns" /etc/nsswitch.conf ;
      fi ;
    fi ;
  fi
}

cfg_sudo_nopasswd() { # requires sudo/root access
  sudoersd_dir=${1:-/etc/sudoers.d}
  groupX=wheel

  . /etc/os-release
  if [ ! -e /etc/os-release ] && [ -f /usr/lib/os-release ] ; then
    . /usr/lib/os-release ;
  fi
  if [ 'debian' = "${ID_LIKE}" ] ; then
    groupX=sudo ;
  fi

  #${sed_inplace} "/^[^#].*requiretty/ s|^|#|" [/usr/[local|pkg]]/etc/sudoers
  if [ -z "$(grep '^%${groupX} .* NOPASSWD: ALL' ${sudoersd_dir}/99_${groupX}nopasswd)" ] ; then
    cat << EOF | EDITOR="tee -a" visudo -f ${sudoersd_dir}/99_${groupX}nopasswd ;
#Defaults:%${groupX} !requiretty
%${groupX} ALL=(ALL:ALL) NOPASSWD: ALL

EOF
  fi
}

cfg_inputrc_histsearch() { # requires sudo/root access
  #if command -v bind > /dev/null ; then
  if [ 'Linux' = "$(uname -s)" ] ; then
    if ! grep -q -E "history.*-search" /etc/skel/.inputrc ; then
      cat << EOF >> /etc/skel/.inputrc
"\e[A": history-search-backward
"\e[B": history-search-forward

EOF
    fi ;
  fi
}

check_clamav() {
	if command -v curl > /dev/null ; then
    (cd /tmp ; curl --insecure --location https://secure.eicar.org/eicar.com.txt)
	elif command -v wget > /dev/null ; then
    (cd /tmp ; wget --no-check-certificate https://secure.eicar.org/eicar.com.txt)
	elif command -v aria2c > /dev/null ; then
    (cd /tmp ; aria2c --check-certificate=false -d . https://secure.eicar.org/eicar.com.txt)
	elif command -v fetch > /dev/null ; then
    (cd /tmp ; fetch --retry --mirror --no-verify-peer https://secure.eicar.org/eicar.com.txt)
	elif command -v ftp > /dev/null ; then
	  export FTPSSLNOVERIFY=1 ;
    (cd /tmp ; ftp -S dont https://secure.eicar.org/eicar.com.txt || ftp https://secure.eicar.org/eicar.com.txt)
	else
    echo "Cannot download clamav eicar.com.txt" ;
    exit 1 ;
	fi
  freshclam --verbose ; sleep 3 ; freshclam --list-mirrors ; sleep 5
  clamscan --verbose /tmp/eicar.com.txt ; sleep 5 ; clamscan --recursive /tmp
  rm /tmp/eicar.com.txt
}

cfg_sshd() { # requires sudo/root access
  skeldir_ssh=${1:-/etc/skel/.ssh}

  # ensure that there is a trailing newline before attempting to concatenate
  ${sed_inplace} '$a\' /etc/ssh/sshd_config

  mkdir -p /etc/ssh/sshd_config.d
  if [ -z "$(grep 'Include /etc/ssh/sshd_config.d/*.conf' /etc/ssh/sshd_config)" ] ; then
    echo "Include /etc/ssh/sshd_config.d/*.conf" >> /etc/ssh/sshd_config ;
  fi
  #${sed_inplace} "s|.*PermitRootLogin|#PermitRootLogin|" /etc/ssh/sshd_config
  echo "PermitRootLogin no" > /etc/ssh/sshd_config.d/99-rootlogin.conf
  cat << EOF > /etc/ssh/sshd_config.d/99-custom.conf
UseDNS no
GSSAPIAuthentication no
HostKeyAlgorithms ssh-ed25519-cert-v01@openssh.com,rsa-sha2-512-cert-v01@openssh.com,rsa-sha2-256-cert-v01@openssh.com,ssh-ed25519,rsa-sha2-512,rsa-sha2-256
PubkeyAcceptedKeyTypes ssh-ed25519-cert-v01@openssh.com,rsa-sha2-512-cert-v01@openssh.com,rsa-sha2-256-cert-v01@openssh.com,ssh-ed25519,rsa-sha2-512,rsa-sha2-256

HostKey /etc/ssh/ssh_host_ed25519_key
HostKey /etc/ssh/ssh_host_rsa_key

TrustedUserCAKeys /etc/ssh/sshca-id_rsa.pub
RevokedKeys /etc/ssh/krl.krl
#HostCertificate /etc/ssh/ssh_host_ed25519_key-cert.pub
#HostCertificate /etc/ssh/ssh_host_rsa_key-cert.pub

#Match User packer,user2
Match User packer
  X11Forwarding yes
  AllowTcpForwarding yes
  X11UseLocalHost yes
  X11DisplayOffset 10

EOF

  sshca_pubkey="${skeldir_ssh}/publish_krls/sshca-id_rsa.pub"
  sshca_krl="${skeldir_ssh}/publish_krls/krl.krl"
  if [ -e ${sshca_pubkey} ] ; then
    #for iprange in '192.168.0.0/16' '172.16.0.0/12' '10.0.0.0/8' 'fd00::/8' ; do
    for iprange in '192.168.0.0/16' ; do
      if [ "$(grep \"^@cert-authority ${iprange}\" ${skeldir_ssh}/known_hosts)" ] ; then
        ${sed_inplace} "s|@cert-authority ${iprange}.*|@cert-authority ${iprange} $(cat ${sshca_pubkey})|" ${skeldir_ssh}/known_hosts ;
      else
        cp -a ${skeldir_ssh}/known_hosts.sample ${skeldir_ssh}/known_hosts ;
        echo "@cert-authority ${iprange} $(cat ${sshca_pubkey})" >> \
          ${skeldir_ssh}/known_hosts ;
      fi ;
    done ;
    cp -a ${sshca_krl} ${sshca_pubkey} /etc/ssh/ ;
  fi
}

cfg_shell_keychain() { # may require sudo/root access
  shell_rc=${1:-/etc/skel/.bashrc}

  if ! grep -q -E 'eval `keychain --agents.*--eval`' ${shell_rc} ; then
    if [ "`echo ${SHELL} | grep csh`" ] ; then
      #shell_rc=${1:-/usr/share/skel/dot.cshrc} ;
      cat << EOF >> ${shell_rc} ;
eval \`keychain --agents gpg,ssh --eval\`
unsetenv SSH_AGENT_PID
setenv GPG_TTY \`tty\`
gpg-connect-agent updatestartuptty /bye > /dev/null
setenv SSH_AUTH_SOCK \`gpgconf --list-dirs agent-ssh-socket\`

EOF
    else
      #shell_rc=${1:-/etc/skel/.bashrc} ;
      cat << EOF >> ${shell_rc} ;
eval \`keychain --agents gpg,ssh --eval\`
unset SSH_AGENT_PID
export GPG_TTY=\`tty\`
gpg-connect-agent updatestartuptty /bye > /dev/null
export SSH_AUTH_SOCK=\`gpgconf --list-dirs agent-ssh-socket\`

EOF
    fi ;
  fi
}

share_nfs_data0() { # requires sudo/root access
  sharednode=${1:-localhost.local}
  #FreeBSD NFS server example /etc/exports
    #/mnt/Data0  -network 192.168.0/24 -maproot=0
  #Linux NFS server example /etc/exports
    #/mnt/Data0  192.168.*.*(rw,sync,root_squash,anongid=100)

  ${sed_inplace} "/^9p_Data0 / s|^9p_Data0|#9p_Data0|" /etc/fstab
  if [ "Linux" = "`uname -s`" ] ; then
    nfsmount="#${sharednode}:/mnt/Data0  /media/nfs_Data0  nfs  rw,noauto,users,rsize=8192,wsize=8192,timeo=14,_netdev  0  0" ;
  else
    nfsmount="#${sharednode}:/mnt/Data0  /media/nfs_Data0  nfs  rw,noauto  0  0" ;
  fi ;
  if grep -q -E "^.*:/mnt/Data0.*" /etc/fstab ; then
    ${sed_inplace} "s|^.*:/mnt/Data0.*|${nfsmount}|" /etc/fstab ;
  else
    echo "${nfsmount}" >> /etc/fstab ;
  fi
  mkdir -p /media/nfs_Data0
}

cfg_printer_pdf() { # requires sudo/root access
  etcdir_cups=${1:-/etc/cups} ; cupsdir_ppd=${2:-/usr/share/cups/model}

  if grep -q -E "^Out .*" ${etcdir_cups}/cups-pdf.conf ; then
    ${sed_inplace} "s|^Out .*|Out \${HOME}/Documents/PDF|" \
      ${etcdir_cups}/cups-pdf.conf ;
  else
    echo "Out \${HOME}/Documents/PDF" >> ${etcdir_cups}/cups-pdf.conf ;
  fi
  lpadmin -E -U root -p CUPS_PDF -v "cups-pdf:/" \
    -i ${cupsdir_ppd}/CUPS-PDF_opt.ppd
  lpadmin -E -U root -d CUPS_PDF
}

cfg_printer_default() { # requires sudo/root access
  sharednode=${1:-localhost.local} ; printname=${2:-printer1}
  ## Configure printer using CUPS web interface
  # w3m http://localhost:631

  #lpadmin -E -U root -p ${printname} -D "${printname}" -L localhost \
  #  -v "ipp://${sharednode}/printers/${printname}"
  lpadmin -E -U root -p ${printname} \
    -v "ipp://${sharednode}/printers/${printname}"
  lpadmin -E -U root -d ${printname}
}

cfg_xorgtouchpad() { # requires sudo/root access
  xorgconfd_dir=${1:-/etc/X11/xorg.conf.d}

  # enable touchpad tapping
  for confX in 10-evdev.conf 40-libinput.conf ; do
    ${sed_inplace} '/MatchIsTouchpad/a \ \ \ \ \ \ \ \ Option "Tapping" "on"' \
      ${xorgconfd_dir}/${confX} ;
  done
  ## ??? egrep -i 'synap|alps|etps|elan' /proc/bus/input/devices
  #libinput list-devices ; xinput --list
  #xinput list-props XX [; xinput disable YY] # by id, list-props or disable
  #xinput set-prop <deviceid|devicename> <deviceproperty> <value>
}

cfg_xdguserdirs() { # requires sudo/root access
  etcdir_xdg=${1:-/etc/xdg}

  # add directory bin to XDG directories config
  if [ -z "$(grep '^BIN=bin' ${etcdir_xdg}/user-dirs.defaults)" ] ; then
    echo 'BIN=bin' >> ${etcdir_xdg}/user-dirs.defaults ;
  fi
  export LANG=en_US.UTF-8 ; export CHARSET=UTF-8
  xdg-user-dirs-update ; chmod 1777 /tmp
}

#========================================================================#
${@}
