#!/bin/sh

#[aria2c --check-certificate=false | fetch --no-verify-peer | ftp -S dont | \
#  wget -N --no-check-certificate | curl -kOL]
#aria2c --check-certificate=false <url_prefix>/script.sh

#========================================================================#
sed_inplace=${sed_inplace:-"sed -i ''"}

cfg_sshd() { # requires sudo/root access
    SSHD_CONFIG="/etc/ssh/sshd_config"

    # ensure that there is a trailing newline before attempting to concatenate
    ${sed_inplace} '$a\' "$SSHD_CONFIG"

    USEDNS="UseDNS no"
    if grep -q -E "^[[:space:]]*UseDNS" "$SSHD_CONFIG" ; then
        ${sed_inplace} "s|^\s*UseDNS.*|${USEDNS}|" "$SSHD_CONFIG" ;
    else
        echo "$USEDNS" >> "$SSHD_CONFIG" ;
    fi

    GSSAPI="GSSAPIAuthentication no"
    if grep -q -E "^[[:space:]]*GSSAPIAuthentication" "$SSHD_CONFIG" ; then
        ${sed_inplace} "s|^\s*GSSAPIAuthentication.*|${GSSAPI}|" "$SSHD_CONFIG" ;
    else
        echo "$GSSAPI" >> "$SSHD_CONFIG" ;
    fi
}

cfg_shell_keychain() { # may require sudo/root access
    shell_rc=${1:-/usr/share/skel/dot.cshrc}
    sh -c 'cat' << EOF >> ${shell_rc}
eval \$(keychain --agents gpg,ssh --eval)

EOF
}

cfg_printer_default() { # requires sudo/root access
    NODE=${1:-localhost.local} ; NAME=${2:-printer1}
    ## Configure printer using CUPS web interface
    # w3m http://localhost:631

    #lpadmin -E -U root -p ${NAME} -D "${NAME}" -L localhost -E -v "ipp://${NODE}/printers/${NAME}"
    #lpadmin -E -U root -d ${NAME}
    lpadmin -E -U root -p $NAME -E -v "ipp://${NODE}/printers/${NAME}"
    lpadmin -E -U root -d $NAME
}

cfg_printer_pdf() { # requires sudo/root access
    PPD=${1:-/usr/local/share/cups/model/CUPS-PDF.ppd}
    CUPS_PDF_CONF=${2:-/usr/local/etc/cups/cups-pdf.conf}
    lpadmin -E -U root -p CUPS_PDF -E -v "cups-pdf:/" -i $PPD
    ${sed_inplace} '/Out / s|^[#]*\(Out .*\)|#\1|' $CUPS_PDF_CONF
	echo "Out \${HOME}/Documents/PDF" >> $CUPS_PDF_CONF
}

share_nfs_data0() { # requires sudo/root access
    NODE=${1:-localhost.local}
    #FreeBSD NFS server example /etc/exports
      #/mnt/Data0  -network 192.168.0/24 -maproot=0
    #Linux NFS server example /etc/exports
      #/mnt/Data0  192.168.*.*(rw,sync,root_squash,anongid=100)
    
    ${sed_inplace} "/^Data0 / s|^Data0|#Data0|" /etc/fstab
    echo "${NODE}:/mnt/Data0  /media/nfs_Data0  nfs  rw,noauto  0  0" \
        >> /etc/fstab
    mkdir -p /media/nfs_Data0
}

#========================================================================#
$@
