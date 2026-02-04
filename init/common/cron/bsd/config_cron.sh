#!/bin/sh

SCRIPTPARENT=${SCRIPTPARENT:-$(dirname ${0})}

if [ 'FreeBSD' = "$(uname -s)" ] ; then
  sed_inplace=${sed_inplace:-"sed -i ''"} ;
else
  sed_inplace=${sed_inplace:-"sed -i"} ;
fi

#if [ 'FreeBSD' = "$(uname -s)" ] ; then
#  #if [ -z "$(crontab -u root -l | grep -e 'find /tmp/\* .*-type d')" ] ; then
#  #  (crontab -u root -l ; echo "@daily find /tmp/* -maxdepth 0 -type d -atime +15 -print0 | xargs -0 rm -irf") | \
#  #    crontab -u root - ;
#  #fi
#  #if [ -z "$(crontab -u root -l | grep -e 'find /tmp/\* .*-type f')" ] ; then
#  #  (crontab -u root -l ; echo "@daily find /tmp/* -maxdepth 0 -type f -atime +15 -print0 | xargs -0 rm -if") | \
#  #    crontab -u root - ;
#  #fi
#  cat << EOF > /etc/periodic/daily/999.cleantmp ;
##!/bin/sh
#
#find /tmp/* -maxdepth 0 -type d -atime +15 -print0 | xargs -0 rm -irf
#find /tmp/* -maxdepth 0 -type f -atime +15 -print0 | xargs -0 rm -if
#
#EOF
#  chmod +x /etc/periodic/daily/999.cleantmp ;
#fi
for periodX in daily weekly monthly ; do
  if [ ! 'FreeBSD' = "$(uname -s)" ] ; then
    jobstampanacron_file="/etc/${periodX}.local" ;
    if [ -z "$(grep '#!/bin/sh' ${jobstampanacron_file})" ] ; then
      printf '#!/bin/sh\n\n' >> ${jobstampanacron_file} ;
    fi ;
  else
    jobstampanacron_file="/etc/periodic/${periodX}/0anacron" ;
    printf '#!/bin/sh\n\n' > ${jobstampanacron_file} ;
  fi ;
  if [ -z "$(grep 'anacron -u ${periodX}' ${jobstampanacron_file})" ] ; then
    cat << EOF >> ${jobstampanacron_file} ;

#anacron -u {job} --> date +%Y%m%d > /var/spool/anacron/{job}
/usr/local/sbin/anacron -u ${periodX}
EOF
  fi ;
  chmod +x ${jobstampanacron_file} ;
  if [ 'NetBSD' = "$(uname -s)" ] ; then
    ${sed_inplace} "s|/usr/local/sbin|/usr/pkg/sbin|" ${jobstampanacron_file} ;
  fi ;
done

mkdir -p /usr/local/etc
for fileX in /var/cron/tabs/root /etc/crontab /usr/local/etc/anacrontab \
    /usr/pkg/etc/anacrontab ; do
  cp -an ${fileX} ${fileX}.orig ;
  if [ ! 'FreeBSD' = "$(uname -s)" ] ; then
    ${sed_inplace} "/\/etc\/[daiwekmonth]*ly/ s|^|#|" ${fileX} ;
  else
    ${sed_inplace} "/periodic [daiwekmonth]*ly/ s|^|#|" ${fileX} ;
  fi ;
done

for fileX in /usr/local/etc/anacrontab /usr/pkg/etc/anacrontab ; do
  cp -n ${SCRIPTPARENT}/anacrontab_head.sample ${fileX} ;
  cat ${SCRIPTPARENT}/anacrontab_tail.sample >> ${fileX} ;
done
cp -n ${SCRIPTPARENT}/crontab_syshead.sample /etc/crontab
mkdir -p /etc/cron.d ; touch /etc/crontab
#cat ${SCRIPTPARENT}/crond_periodic.sample >> /etc/crontab
#(crontab -u root -l ; cat ${SCRIPTPARENT}/crontab_roottail.sample
#) | crontab -u root -
cat ${SCRIPTPARENT}/crond_periodic.sample >> /etc/cron.d/periodic
echo "02  6-22    *   *   *   root    /usr/local/sbin/anacron -s" > \
  /etc/cron.d/anacron

for fileX in /var/cron/tabs/root /etc/crontab /usr/local/etc/anacrontab \
    /usr/pkg/etc/anacrontab /etc/cron.d/periodic /etc/cron.d/anacron ; do
  if [ ! 'FreeBSD' = "$(uname -s)" ] ; then
    ${sed_inplace} "s|nice periodic \([daiwekmonth]*ly\)|nice /bin/sh /etc/\1|" ${fileX} ;
    if [ 'NetBSD' = "$(uname -s)" ] ; then
      ${sed_inplace} "s|/usr/local/sbin|/usr/pkg/sbin|" ${fileX} ;
    fi ;
    if [ 'OpenBSD' = "$(uname -s)" ] ; then
      ${sed_inplace} "s|tail -vn+1|tail -n+1 .|" ${fileX} ;
    fi ;
  fi ;
done
