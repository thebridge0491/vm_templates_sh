#!/bin/sh

SCRIPTPARENT=${SCRIPTPARENT:-$(dirname ${0})}

if [ 'FreeBSD' = "$(uname -s)" ] ; then
  sed_inplace=${sed_inplace:-"sed -i ''"} ;
else
  sed_inplace=${sed_inplace:-"sed -i"} ;
fi

# smtpd.conf location varies:
#  /etc/mail/smtpd.conf: OpenBSD, Alpine Linux
#  /etc/smtpd/smtpd.conf: Void Linux, Arch Linux
#  /etc/smtpd.conf: Debian
found_smtpdconf=$(find /etc -name smtpd.conf | head -n1)
found_smtpdconf=${found_smtpdconf:-/etc/mail/smtpd.conf}

local MOD_LINENO=0
if [ -z "$(grep 'local ! rcpt-to' ${found_smtpdconf})" ] ; then
  cp -an ${found_smtpdconf} ${found_smtpdconf}.orig ;
  MOD_LINENO=$(grep -n "^table aliases" ${found_smtpdconf} | cut -d: -f1) ;
  #${sed_inplace} "${MOD_LINENO}i\
  ##table domains { $(hostname -s || hostname), localhost }
  #" ${found_smtpdconf} ;
  awk "NR==${MOD_LINENO}{print \"#table domains { $(hostname -s || hostname), localhost }\"}1" \
    ${found_smtpdconf} > ${found_smtpdconf}.new ;
  [ -e ${found_smtpdconf}.new ] && \
    mv ${found_smtpdconf}.new ${found_smtpdconf} ;
  MOD_LINENO=$(grep -n "^action \"local.*mbox" ${found_smtpdconf} | cut -d: -f1) ;
  #${sed_inplace} "${MOD_LINENO}i\
  #
  #action \"local_maildir\" maildir \"/var/mail/%{rcpt.user}\" alias <aliases>
  #match from local for local ! rcpt-to \"root\" action \"local_maildir\"
  #
  #" ${found_smtpdconf} ;
  awk "NR==${MOD_LINENO}{print \"\naction 'local_maildir' maildir '/var/mail/%{rcpt.user}' alias <aliases>\nmatch from local for local ! rcpt-to 'root' action 'local_maildir'\n\"}1" \
    ${found_smtpdconf} > ${found_smtpdconf}.new ;
  [ -e ${found_smtpdconf}.new ] && \
    mv ${found_smtpdconf}.new ${found_smtpdconf} ;
  ${sed_inplace} "/'local_maildir'/ s|'|\"|g" ${found_smtpdconf} ;
fi
