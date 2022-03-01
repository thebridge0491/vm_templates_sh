#!/bin/sh

#[aria2c --check-certificate=false | fetch --no-verify-peer | ftp [-S dont] | \
#  wget -N --no-check-certificate | curl -kOL]
#aria2c --check-certificate=false <url_prefix>/script.sh

#========================================================================#
SED_INPLACE=${SED_INPLACE:-"sed -i"}

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
    SSHD_CONFIG="/etc/ssh/sshd_config"

    # ensure that there is a trailing newline before attempting to concatenate
    ${SED_INPLACE} '$a\' $SSHD_CONFIG

    PERMITROOT="PermitRootLogin no"
    USEDNS="UseDNS no"
    GSSAPI="GSSAPIAuthentication no"
    if grep -q -E "^[[:space:]]*PermitRootLogin" $SSHD_CONFIG ; then
        ${SED_INPLACE} "s|^\s*PermitRootLogin.*|${PERMITROOT}|" $SSHD_CONFIG ;
    else
        echo "$PERMITROOT" >> $SSHD_CONFIG ;
    fi
    if grep -q -E "^[[:space:]]*UseDNS" $SSHD_CONFIG ; then
        ${SED_INPLACE} "s|^\s*UseDNS.*|${USEDNS}|" $SSHD_CONFIG ;
    else
        echo "$USEDNS" >> $SSHD_CONFIG ;
    fi
    if grep -q -E "^[[:space:]]*GSSAPIAuthentication" $SSHD_CONFIG ; then
        ${SED_INPLACE} "s|^\s*GSSAPIAuthentication.*|${GSSAPI}|" $SSHD_CONFIG ;
    else
        echo "$GSSAPI" >> $SSHD_CONFIG ;
    fi

    sshca_pubkey="${skeldir_ssh}/publish_krls/sshca-id_rsa.pub"
    sshca_krl="${skeldir_ssh}/publish_krls/krl.krl"
    if [ -e $sshca_pubkey ] ; then
	    #for iprange in '192.168.0.0/16' '172.16.0.0/12' '10.0.0.0/8' 'fd00::/8' ; do
	    for iprange in '192.168.0.0/16' ; do
	      if [ "$(grep \"^@cert-authority $iprange\" ${skeldir_ssh}/known_hosts)" ] ; then
	        ${SED_INPLACE} "s|@cert-authority $iprange.*|@cert-authority $iprange $(cat $sshca_pubkey)|" ${skeldir_ssh}/known_hosts ;
	      else
	        echo "@cert-authority $iprange $(cat $sshca_pubkey)" >> \
		      ${skeldir_ssh}/known_hosts ;
	      fi ;
	    done ;
	    cp $sshca_krl $sshca_pubkey /etc/ssh/ ;
    fi
    cat << EOF >> $SSHD_CONFIG
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
}

cfg_shell_keychain() { # may require sudo/root access
    shell_rc=${1:-/etc/skel/.bashrc}

    if ! grep -q -E 'eval `keychain --agents.*--eval`' ${shell_rc} ; then
      if [ "`echo $SHELL | grep csh`" ] ; then
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

    ${SED_INPLACE} "/^9p_Data0 / s|^9p_Data0|#9p_Data0|" /etc/fstab
    if [ "Linux" = "`uname -s`" ] ; then
      nfsmount="#${sharednode}:/mnt/Data0  /media/nfs_Data0  nfs  rw,noauto,users,rsize=8192,wsize=8192,timeo=14,_netdev  0  0" ;
    else
      nfsmount="#${sharednode}:/mnt/Data0  /media/nfs_Data0  nfs  rw,noauto  0  0" ;
    fi ;
    if grep -q -E "^.*:/mnt/Data0.*" /etc/fstab ; then
        ${SED_INPLACE} "s|^.*:/mnt/Data0.*|${nfsmount}|" /etc/fstab ;
    else
        echo "$nfsmount" >> /etc/fstab ;
    fi
    mkdir -p /media/nfs_Data0
}

cfg_printer_pdf() { # requires sudo/root access
    etcdir_cups=${1:-/etc/cups} ; cupsdir_ppd=${2:-/usr/share/cups/model}

    if grep -q -E "^Out .*" $etcdir_cups/cups-pdf.conf ; then
        ${SED_INPLACE} "s|^Out .*|Out \${HOME}/Documents/PDF|" $etcdir_cups/cups-pdf.conf ;
    else
        echo "Out \${HOME}/Documents/PDF" >> $etcdir_cups/cups-pdf.conf ;
    fi
    lpadmin -E -U root -p CUPS_PDF -v "cups-pdf:/" -i $cupsdir_ppd/CUPS-PDF_opt.ppd
    lpadmin -E -U root -d CUPS_PDF
}

cfg_printer_default() { # requires sudo/root access
    sharednode=${1:-localhost.local} ; printname=${2:-printer1}
    ## Configure printer using CUPS web interface
    # w3m http://localhost:631

    #lpadmin -E -U root -p ${printname} -D "${printname}" -L localhost -v "ipp://${sharednode}/printers/${printname}"
    lpadmin -E -U root -p $printname -v "ipp://${sharednode}/printers/${printname}"
    lpadmin -E -U root -d $printname
}

#========================================================================#
$@
