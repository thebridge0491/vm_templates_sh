#!/bin/sh

SCRIPTPARENT=${SCRIPTPARENT:-$(dirname ${0})}

. /etc/os-release
if [ ! -e /etc/os-release ] && [ -f /usr/lib/os-release ] ; then
  . /usr/lib/os-release ;
fi

##if [ -z "$(crontab -u root -l | grep -e 'find /tmp/\* .*-type d')" ] ; then
##  echo "@daily find /tmp/* -maxdepth 0 -type d -atime +15 -print0 | xargs -0 rm -irf" | \
##    env EDITOR="tee -a" crontab -u root -e ;
##fi
##if [ -z "$(crontab -u root -l | grep -e 'find /tmp/\* .*-type f')" ] ; then
##  echo "@daily find /tmp/* -maxdepth 0 -type f -atime +15 -print0 | xargs -0 rm -if" | \
##    env EDITOR="tee -a" crontab -u root -e ;
##fi
#if [ 'alpine' = "${ID}" ] ; then
#  dailycleantmp_file=/etc/periodic/daily/900cleantmp ;
#else
#  dailycleantmp_file=/etc/cron.daily/900cleantmp ;
#fi
#cat << EOF > ${dailycleantmp_file}
##!/bin/sh
#
#find /tmp/* -maxdepth 0 -type d -atime +15 -print0 | xargs -0 rm -irf
#find /tmp/* -maxdepth 0 -type f -atime +15 -print0 | xargs -0 rm -if
#
#EOF
#chmod +x ${dailycleantmp_file}
for periodX in daily weekly monthly ; do
  if [ 'alpine' = "${ID}" ] ; then
    jobstampanacron_file="/etc/periodic/${periodX}/0anacron" ;
  else
    jobstampanacron_file="/etc/cron.${periodX}/0anacron" ;
  fi ;
  if [ -z "$(grep 'anacron -u ${periodX}' ${jobstampanacron_file})" ] ; then
    cat << EOF > ${jobstampanacron_file} ;
#!/bin/sh

#anacron -u {job} --> date +%Y%m%d > /var/spool/anacron/{job}
anacron -u cron.${periodX}
EOF
  fi ;
  chmod +x ${jobstampanacron_file} ;
done
if [ 'alpine' = "${ID}" ] ; then
  cp -a ${SCRIPTPARENT}/cron_daily_999dailystats.sample \
    /etc/periodic/daily/999dailystats ;
  chmod +x /etc/periodic/daily/999dailystats ;
else
  cp -a ${SCRIPTPARENT}/cron_daily_999dailystats.sample \
    /etc/cron.daily/999dailystats ;
  chmod +x /etc/cron.daily/999dailystats ;
fi

#Note: (Linux) user crontabs --
#  /var/spool/cron/{user}: Void, Arch, Suse, Redhat, Mageia, PCLinuxOS
#  /var/spool/cron/crontabs/{user}: Alpine, Debian
for fileX in /var/spool/cron/root /var/spool/cron/crontabs/root /etc/crontab \
    /etc/anacrontab ; do
  cp -an ${fileX} ${fileX}.orig ;
  if [ 'alpine' = "${ID}" ] ; then
    sed -i "/\/etc\/periodic\/[daiwekmonth]*ly/ s|^|#|" ${fileX} ;
  else
    sed -i "/cron.[daiwekmonth]*ly/ s|^|#|" ${fileX} ;
  fi ;
  if [ -n "$(echo ${ID} | grep -e opensuse)" ] ; then
    sed -i "/run-crons/ s|^|#|" ${fileX} ;
  fi ;
done

cp -n ${SCRIPTPARENT}/anacrontab_head.sample /etc/anacrontab
cat ${SCRIPTPARENT}/anacrontab_tail.sample >> /etc/anacrontab
cp -n ${SCRIPTPARENT}/crontab_syshead.sample /etc/crontab
mkdir -p /etc/cron.d ; touch /etc/crontab
#cat ${SCRIPTPARENT}/crond_periodic.sample >> /etc/crontab
if [ 'alpine' = "${ID}" ] ; then
  (crontab -u root -l ; cat ${SCRIPTPARENT}/crontab_roottail.sample
  ) | crontab -u root - ;
  printf '#!/bin/sh\nanacron -s\n' > /etc/periodic/hourly/0anacron ;
  chmod +x /etc/periodic/hourly/0anacron ;
else
  cat ${SCRIPTPARENT}/crond_periodic.sample >> /etc/cron.d/periodic ;
  #printf '#!/bin/sh\n#anacron -s\n' > /etc/cron.hourly/0anacron ;
  #chmod +x /etc/cron.hourly/0anacron ;
  echo "02  6-22    *   *   *   root    anacron -s" > /etc/cron.d/anacron ;
fi

for fileX in /var/spool/cron/root /var/spool/cron/crontabs/root /etc/crontab \
    /etc/anacrontab ; do
  if [ 'alpine' = "${ID}" ] ; then
    sed -i "/run-parts/ s|/etc/cron.\([daiwekmonth]*ly\)|/etc/periodic/\1|" ${fileX} ;
  fi ;
  if [ -n "$(run-parts --help | grep -e '--report')" ] ; then
    sed -i "/run-parts/ s|run-parts /etc|run-parts --report /etc|" ${fileX} ;
  fi ;
done
