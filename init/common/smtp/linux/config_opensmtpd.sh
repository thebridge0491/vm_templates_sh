#!/bin/sh

# smtpd.conf location varies:
#  /etc/mail/smtpd.conf: OpenBSD, Alpine Linux
#  /etc/smtpd/smtpd.conf: Void Linux, Arch Linux
#  /etc/smtpd.conf: Debian
found_smtpdconf=$(find /etc -name smtpd.conf | head -n1)
found_smtpdconf=${found_smtpdconf:-/etc/mail/smtpd.conf}

if [ -z "$(grep 'local ! rcpt-to' ${found_smtpdconf})" ] ; then
  cp -an ${found_smtpdconf} ${found_smtpdconf}.orig ;
  sed -i "/^table aliases/i\
#table domains { $(hostname -s || hostname), localhost }" \
    ${found_smtpdconf} ;
  sed -i '/^action "local" maildir/ s|maildir|mbox|' ${found_smtpdconf} ;
  sed -i '/^action "local" mbox/i\
action "local_maildir" maildir "/var/spool/mail/%{rcpt.user}" alias <aliases>\
match for local ! rcpt-to "root" action "local_maildir"\
' \
    ${found_smtpdconf} ;
fi
