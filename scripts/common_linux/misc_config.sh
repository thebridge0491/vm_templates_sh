#!/bin/sh

#[aria2c --check-certificate=false | wget -N --no-check-certificate | curl -kOL]
#aria2c --check-certificate=false <url_prefix>/script.sh

#========================================================================#
cfg_sshd() { # requires sudo/root access
    SSHD_CONFIG="/etc/ssh/sshd_config"

    # ensure that there is a trailing newline before attempting to concatenate
    sed -i -e '$a\' "$SSHD_CONFIG"

    USEDNS="UseDNS no"
    if grep -q -E "^[[:space:]]*UseDNS" "$SSHD_CONFIG" ; then
        sed -i "s|^\s*UseDNS.*|${USEDNS}|" "$SSHD_CONFIG" ;
    else
        echo "$USEDNS" >> "$SSHD_CONFIG" ;
    fi

    GSSAPI="GSSAPIAuthentication no"
    if grep -q -E "^[[:space:]]*GSSAPIAuthentication" "$SSHD_CONFIG" ; then
        sed -i "s|^\s*GSSAPIAuthentication.*|${GSSAPI}|" "$SSHD_CONFIG" ;
    else
        echo "$GSSAPI" >> "$SSHD_CONFIG" ;
    fi   
}

cfg_shell_keychain() { # may require sudo/root access
    shell_rc=${1:-/etc/skel/.bashrc}
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
    PPD=${1:-/usr/share/cups/model/CUPS-PDF.ppd}
    CUPS_PDF_CONF=${2:-/etc/cups/cups-pdf.conf}
    lpadmin -E -U root -p CUPS_PDF -E -v "cups-pdf:/" -i $PPD
    sed -i '/Out / s|^[#]*\(Out .*\)|#\1|' $CUPS_PDF_CONF
	echo "Out \${HOME}/Documents/PDF" >> $CUPS_PDF_CONF
}

share_nfs_data0() { # requires sudo/root access
    NODE=${1:-localhost.local}
    #FreeBSD NFS server example /etc/exports
      #/mnt/Data0  -network 192.168.0/24 -maproot=0
    #Linux NFS server example /etc/exports
      #/mnt/Data0  192.168.*.*(rw,sync,root_squash,anongid=100)
    
    sed -i "/^Data0 / s|^Data0|#Data0|" /etc/fstab
    echo "${NODE}:/mnt/Data0  /media/nfs_Data0  nfs  rw,noauto,users,rsize=8192,wsize=8192,timeo=14,_netdev  0  0" \
        >> /etc/fstab
    mkdir -p /media/nfs_Data0
}

#===========================================================
$@
