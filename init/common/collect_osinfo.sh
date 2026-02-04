#!/bin/sh

# nc -l [-p] {port} > file ## nc -w3 {host} {port} < file  # netcat xfr
# ssh user@ipaddr "sudo sh -xs - arg1 argN" < script.sh  # w/ sudo
# ssh user@ipaddr "su [-m root] -c 'sh -xs - arg1 argN'" < script.sh

#[aria2c --check-certificate=false | fetch --no-verify-peer | ftp [-S dont] | \
#  wget -N --no-check-certificate | curl -kOL]
#aria2c --check-certificate=false <url_prefix>/script.sh

MACHINE=$(uname -m)
OS_NAME=$(uname -s) ; sep='#--------------------#' ; NAME="${OS_NAME}"
case ${OS_NAME} in
  'Darwin') NAME=$(sw_vers -productName) ;;
  'FreeBSD'|'OpenBSD'|'NetBSD'|'Linux')
    #NAME=$(lsb_release -i)
    test -e /etc/os-release && . /etc/os-release ;
    if [ ! -e /etc/os-release ] && [ -f /usr/lib/os-release ] ; then
      . /usr/lib/os-release ;
    fi ;
    #sudo tar -xf /root/scripts.tar ;
    sudo find /root/scripts -name 'distro_pkg*' -exec cp -a {} /tmp/ \; ;
    sudo find /root/init -name 'config_samples*' -exec cp -a {} /var/tmp/ \; ;
    sudo chmod 0644 /var/tmp/config_samples* ;
    . /tmp/distro_pkgs.ini ; . /tmp/distro_pkgmgr_funcs.sh ;
    sudo ${pkgmgr_update} > /dev/stderr ;;
esac

cp -a ${0} /var/tmp/

#===========================================================================#
concat_sep() {
  if [ -f "${@}" ] ; then
    printf "${sep}\n${@}\n" | cat - ${@} ;
  else
    printf "${sep}\n${@}\n" ;
    eval `echo ${@}` ;
  fi
}
sep_content() {
  printf "${sep}\n"
  if [ "OpenBSD" = "`uname -s`" ] ; then
    tail -n+1 . ${@} ;
  else
    tail -vn+1 ${@} ;
  fi
}

sep_cmd() {
  printf "${sep}\n${@}\n" ; eval `echo ${@}`
}

lang_devel_versions() {
  echo "(${NAME} ${MACHINE})" 'lang_devel_versions' ; echo ${sep}
  echo "" ; echo "lang_c" ; echo ""
  for cmd in 'gcc --version' 'clang --version' 'cmake --version' \
      'automake --version' ; do
    sep_cmd "${cmd} | head -n1" ;
  done
  echo ${sep} ; echo "(gmake --version || make --version)    $(gmake --version | head -n1 || make --version | head -n1)"
  echo ${sep} ; echo "(swig3.0 -version || swig2.0 -version || swig -version)"
  echo ""
  for cmd in 'swig3.0' 'swig2.0' 'swig' ; do
    echo "$(${cmd} -version | head -n 2)" ;
  done
  for cmd in 'gfortran --version' 'go version' 'gopm --version' ; do
    sep_cmd "${cmd} | head -n1" ;
  done
  echo "" ; echo "lang_rust" ; echo ""
  for cmd in 'rustc --version' 'cargo --version' 'swiftc -version' ; do
    sep_cmd "${cmd} | head -n1" ;
  done
  echo ${sep} ; echo "scalac -version    $(scalac -version 2>&1 | head -n1)"
  echo "" ; echo "lang_oo_c" ; echo ""
  for cmd in 'g++ --version' 'clang++ --version' 'msc -version' ; do
    sep_cmd "${cmd} | head -n1" ;
  done
  #nuget ; #monodevelop
  echo ${sep} ; echo "javac -version    $(javac -version 2>&1 | head -n1)"
  echo ${sep} ; echoo "gradle --version" ; echo "$(gradle --version | head -n 3)"
  for cmd in 'sbt version' 'ant -version' ; do
    sep_cmd "${cmd} | head -n1" ;
  done
  #netbeans ; #eclipse
  sep_cmd 'valac --version | head -n1'
  echo "" ; echo "lang_lisp" ; echo ""
  sep_cmd "clojure -e '(println (str \"Clojure \" (clojure-version)))' | head -n1"
  #leiningen
  sep_cmd 'sbcl -version | head -n1' #; #quicklisp
  sep_cmd 'gosh -V | head -n1'
  echo "" ; echo "lang_ml" ; echo ""
  for cmd in 'fsharpc --help' 'ghc --version' 'stack --version' \
      'ocamlbuild -version' 'opam --version' 'oasis version' 'sml -h' ; do
    sep_cmd "${cmd} | head -n1" ;
  done
  echo "" ; echo "lang_scripting" ; echo ""
  echo ${sep} ; echo "(node --version || nodejs --version) 2> /dev/null"
  echo "$($(node --version || nodejs --version) 2> /dev/null)"
  for cmd in 'npm --version' 'php --version' 'pear -V' 'pecl -V' 'composer -V' ; do
    sep_cmd "${cmd} | head -n1" ;
  done
  echo ${sep} ; echo "(python2 --version || python --version)    $(python2 --version 2>&1 || python --version 2>&1)"
  echo ${sep} ; echo "(pip2 --version || pip --version)    $(pip2 --version 2>&1 || pip --version 2>&1)"
  echo ${sep} ; echo "(pip2 list --local | grep -e setuptools -e invoke || pip list --local | grep -e setuptools -e invoke)"
  echo "$(pip2 list --local | grep -e setuptools -e invoke || pip list --local | grep -e setuptools -e invoke)"
  echo ${sep} ; echo "(jython --version | head -n 2)    $(jython --version 2>&1 | head -n 2)"
  for cmd in 'ruby --version' 'rake --version' 'gem --version' ; do
    sep_cmd "${cmd} | head -n1" ;
  done
  echo ${sep} ; echo "(gem list --local | grep -e hoe)    $(gem list --local | grep -e hoe)"
  for cmd in 'jruby --version' 'lua -v' 'luarocks --version' ; do
    sep_cmd "${cmd} | head -n1" ;
  done
  echo ${sep} ; echo "(perl -v | head -n 2)    $(perl -v | head -n 2)"
  for cmd in 'cpanm --version' 'groovy --version' ; do
    sep_cmd "${cmd} | head -n1" ;
  done
  echo "" ; echo "========================================"
}

bsd_info() {
  echo "(${NAME} ${MACHINE})" 'collect_info'
  logger -s -t user -p user.notice Collect OS info
  sep_cmd 'uname -a'
  if command -v freebsd-version > /dev/null ; then
    sep_cmd 'freebsd-version' ;
  fi
  if [ -f /etc/os-release ] ; then
    sep_cmd 'grep -e NAME -e VERSION -e ID /etc/os-release' ;
  elif [ -f /var/run/os-release ] ; then
    sep_cmd 'grep -e NAME -e VERSION -e ID /var/run/os-release' ;
  fi

  if [ -e /var/run/dmesg.boot ] ; then
    sep_cmd 'cat /var/run/dmesg.boot | grep -ie cpu' ;
    sep_cmd 'cat /var/run/dmesg.boot | grep -ie "memory[ ]*=" -ie "mem[ ]*="' ;
    sep_cmd 'cat /var/run/dmesg.boot | grep -ie network' ;
    sep_cmd 'free -h' ; sep_cmd 'top -bt 0' ;
  fi
  if command -v pciconf > /dev/null ; then
    sep_cmd 'pciconf -lv | grep -ie VGA' ;
    sep_cmd 'pciconf -lv | grep -ie Wireless' ;
    sep_cmd 'pciconf -lv | grep -ie Ethernet' ;
  fi
  if command -v lspci > /dev/null ; then
    sep_cmd "(lspci -kv || lspci -v) | sed -n '/VGA/,/^[[:space:]]*$/p'" ;
    sep_cmd "(lspci -kv || lspci -v) | sed -n '/[Ww]ireless/,/^[[:space:]]*$/p'" ;
    sep_cmd "(lspci -kv || lspci -v) | sed -n '/Ethernet/,/^[[:space:]]*$/p'" ;
  fi
  #if command -v pcidump > /dev/null ; then
  #  sep_cmd 'pcidump -v' ;
  #fi
  sep_cmd 'ls -dp /etc/*syslog*.conf /usr/local/etc/*syslog*.conf'
  cat << EOF
${sep}
(cd /var/log ; ls -dp * | column -xc 78)
`(cd /var/log ; ls -dp * | column -xc 78)`
EOF
  sep_cmd 'sudo tail -v /var/log/messages'

  #configs=$(find -L /boot /etc -type f -maxdepth 2 -name 'rc.conf*' -o -name 'loader.conf*' -o -name 'periodic.conf*' -o -name 'modules.conf*' -o -name 'daily.conf*' -o -name 'weekly.conf*' -o -name 'monthly.conf*')
  #for conf in ${configs} ; do
  #  sep_content ${conf} ;
  #done
  sep_cmd "find -L /boot /etc -type f -maxdepth 2 -name 'rc.conf*' -o -name 'loader.conf*' -o -name 'periodic.conf*' -o -name 'modules.conf*' -o -name 'daily.conf*' -o -name 'weekly.conf*' -o -name 'monthly.conf*' | column -xc 78"
  sep_cmd 'ls -ahldp /bin /sbin /usr/bin /usr/sbin'
  sudoers_files=`find /etc /usr/local/etc /usr/pkg/etc -type f -name sudoers`
  sudoersd_dirs=`find /etc /usr/local/etc /usr/pkg/etc -type d -name sudoers.d`
  sudoers_extras=`find ${sudoersd_dirs} -type f`
  sep_cmd "grep -Hn -e NOPASSWD -e secure_path -e @includedir ${sudoers_files} ${sudoers_extras}"
  sep_cmd 'ls -ld /etc/*ail.rc /var/mail /var/spool/mail $(sudo which smtpctl mailq sendmail mail)'
  sep_cmd 'ls -l /var/mail/ ; sudo smtpctl show queue || sudo mailq 2>&1'
  if [ -n "`sudo nail -u root`" ] ; then
    sep_cmd 'echo q | sudo nail -u root | head -n5 2>&1'
  elif [ -n "`sudo s-nail -u root`" ] ; then
    sep_cmd 'echo q | sudo s-nail -u root | head -n5 2>&1'
  else #elif [ -n "`sudo mail -u root`" ] ; then
    sep_cmd 'echo q | sudo mail -u root | head -n5 2>&1'
  fi
  if [ -n "`sudo nail -u packer`" ] ; then
    sep_cmd 'echo q | sudo nail -u packer | head -n5 2>&1'
  elif [ -n "`sudo s-nail -u packer`" ] ; then
    sep_cmd 'echo q | sudo s-nail -u packer | head -n5 2>&1'
  else #elif [ -n "`sudo mail -u packer`" ] ; then
    sep_cmd 'echo q | sudo mail -u packer | head -n5 2>&1'
  fi
  if [ -e '/usr/local/etc/anacrontab' ] ; then
    sep_cmd 'sudo cat /usr/local/etc/anacrontab' ;
  elif [ -e '/usr/pkg/etc/anacrontab' ] ; then
    sep_cmd 'sudo cat /usr/pkg/etc/anacrontab' ;
  else #elif [ -e '/etc/anacrontab' ] ; then
    sep_cmd 'sudo cat /etc/anacrontab 2>&1' ;
  fi
  sep_cmd 'sudo cat /etc/crontab 2>&1'
  sep_cmd 'sudo crontab -u root -l 2>&1'
  sep_cmd "sudo crontab -u $(id -un) -l 2>&1"
  #sep_cmd "find /etc/* -maxdepth 0 -name '*cron*' | column -xc 78"
  sep_cmd "sudo ls -dp /etc/*cron* /etc/*cron.d/* /etc/periodic/* /etc/daily* /etc/weekly* /etc/monthly* /usr/local/etc/*cron* /usr/local/etc/*cron.d/* /usr/pkg/etc/*cron* /usr/pkg/etc/*cron.d/* /var/cron/* /var/spool/*cron | column -xc 78"
  sep_cmd "ls -dp /etc/ssh/sshd_config* /etc/ssh/sshd_config*/* | column -xc 78"
  if command -v kldstat > /dev/null ; then
    sep_cmd "kldstat | sed 's|^ ||' | tr -s ' ' | cut -w -f5 | column -xc 78" ;
  fi
  if command -v modstat > /dev/null ; then
    sep_cmd "modstat | tr -s ' ' | cut -d' ' -f1 | column -xc 78" ;
  fi
  if command -v service > /dev/null ; then
    sep_cmd 'service -l | sort | column -xc 78' ;
    sep_cmd 'service -e | sort | column -xc 78' ;
  fi
  if command -v rcctl > /dev/null ; then
    sep_cmd 'rcctl ls all | column -xc 78' ;
    sep_cmd 'rcctl ls on | column -xc 78' ;
  fi
  sep_cmd 'sudo pfctl -s info'
  #sep_cmd 'sudo pfctl -s rules -a \*'
  sep_cmd 'grep -e hosts /etc/nsswitch.conf'

  sep_cmd "ls -dp /etc/ntp*.conf /etc/chrony.conf"
  if command -v ntpctl > /dev/null ; then
    sep_cmd 'sudo ntpctl -s peers' ;
  else
    sep_cmd 'sudo ntpq --peers' ;
  fi
  sep_cmd 'date -u'
  sep_cmd 'locale | column -xc 78'
  cat << EOF
${sep}
ifconfig | grep -Ee '^[[:alnum:]]*:.*> .*' | sed 's|^\(.*>\).*|\1|'
$(ifconfig | grep -Ee '^[[:alnum:]]*:.*> .*' | sed 's|^\(.*>\).*|\1|')
EOF
  ifdevs=$(ifconfig | grep '^[a-z]' | grep -ve lo0 | cut -d: -f1)
  cat << EOF
${sep}
ip addr(s):
EOF
  for ifdev in ${ifdevs} ; do
    sep_cmd "ifconfig ${ifdev} | grep -e inet | cut -d' ' -f1-2" ;
  done
  sep_cmd 'hostname -s || hostname' ; sep_cmd 'domainname'
  for file in /etc/hostname /etc/myname /etc/hosts /etc/resolv.conf ; do
    if [ -f ${file} ] ; then sep_cmd "grep -e '^[^# ]' ${file}" ; fi ;
  done
  sep_cmd "ls -dp /var/db/dhclient.leases.* /etc/ifconfig.* /etc/hostname.*" ;
  if [ "OpenBSD" = "${OS_NAME}" ] ; then
    sep_cmd 'sysctl -n hw.uuid' ;
  elif [ "NetBSD" = "${OS_NAME}" ] ; then
    sep_cmd 'sudo sysctl -n machdep.dmi.system-uuid' ;
  else #elif [ "FreeBSD" = "${OS_NAME}" ] ; then
    sep_cmd 'sysctl -n kern.hostuuid' ;
  fi
  sep_cmd 'ls -l /etc/machine-id /var/lib/dbus/machine-id /etc/hostid'
  pkg_repos_sources

  if command -v fdisk > /dev/null ; then
    sep_cmd 'fdisk sd0' ;
  fi
  if command -v dkctl > /dev/null ; then
    sep_cmd 'dkctl sd0 listwedges' ;
  fi
  if command -v disklabel > /dev/null ; then
    sep_cmd 'disklabel -hp m sd0 || disklabel sd0' ;
  fi
  if command -v gpt > /dev/null ; then
    sep_cmd 'gpt show -l sd0' ;
  fi
  if command -v gpart > /dev/null ; then
    sep_cmd 'gpart show -l' ;
    for g_type in label eli ; do
      sep_cmd "geom ${g_type} status -as" ;
    done ;
  fi
  #if command -v zfs > /dev/null ; then
  if [ -n "`df -lhT / | grep -e zfs`" ] ; then
    zfs_ver=$(sudo zfs version | head -n1 | sed 's|zfs-||') ;
    printf "${sep}\nZFS info (${zfs_ver})\n" ; sep_cmd 'zfs version' ;
    sep_cmd 'zpool list -v' ; sep_cmd 'zfs list -t all' ;
  #else
  #elif command -v snapinfo > /dev/null ; then
  elif [ -n "`df -lhT / | grep -e ufs`" ] ; then
    sep_cmd 'find / -flags snapshot' ; sep_cmd 'snapinfo /' ;
  fi
  sep_cmd "grep -e '^[^# ]' /etc/fstab"
  sep_cmd 'df -lhT -c || df -lhc || df -lh'
  sep_cmd 'du -hd 1 / 2> /dev/null | column -xc 78'

  #sep_cmd 'ls -dp /home/* | column -xc 78'
  cat << EOF
${sep}
(cd /home ; ls -dp * | column -xc 78)
`(cd /home ; ls -dp * | column -xc 78)`
EOF
  #sep_cmd "(ls -dp /home/$(id -un)/* || ls -dp /home/packer/*) | column -xc 78"
  if [ -d "/home/$(id -un)" ] ; then
    cat << EOF
${sep}
(cd /home/$(id -un) ; ls -d -- .??*/ */ | column -xc 78)
`(cd /home/$(id -un) ; ls -d -- .??*/ */ | column -xc 78)`
EOF
  else
    cat << EOF
${sep}
(cd /home/packer ; ls -d -- .??*/ */ | column -xc 78)
`(cd /home/packer ; ls -d -- .??*/ */ | column -xc 78)`
EOF
  fi
  sep_cmd 'id'

  cat << EOF
${sep}
TERM: ${TERM} ; SHELL: ${SHELL} ; LANG: ${LANG}
${sep}
PATH: ${PATH}
EOF
  sep_cmd 'lpstat -s' ; sep_cmd 'lpc status'
  cat << EOF
${sep}
/home/$(id -un)/[.xsession|.xinitrc]
EOF
  if [ -e "/home/$(id -un)/.xsession" ] ; then
    sep_content "/home/$(id -un)/.xsession" ;
  elif [ -e "/home/$(id -un)/.xinitrc" ] ; then
    sep_content "/home/$(id -un)/.xinitrc" ;
  else
    echo ${sep} ;
  fi
}

linux_info() {
  echo "(${NAME} ${MACHINE})" 'collect_info'
  logger -s -t user -p user.notice Collect OS info
  sep_cmd 'uname -a' ; sep_cmd 'lsb_release -a'
  sep_content '/proc/version'
  if [ -e /etc/os-release ] ; then
    sep_cmd 'grep -e NAME -e VERSION -e ID /etc/os-release' ;
  elif [ -f /usr/lib/os-release ] ; then
    sep_cmd 'grep -e NAME -e VERSION -e ID /usr/lib/os-release' ;
  fi

  sep_cmd "lscpu | grep -e 'Architecture:' -e 'Model name:'"
  sep_cmd 'free -h' ; sep_cmd 'top -bn 1 -p 0'
  sep_cmd "(lspci -kv || lspci -v) | sed -n '/VGA/,/^\s*$/p'"
  sep_cmd "(lspci -kv || lspci -v) | sed -n '/Wireless/,/^\s*$/p'"
  sep_cmd "(lspci -kv || lspci -v) | sed -n '/Ethernet/,/^\s*$/p'"
  if [ -d /usr/etc ] ; then
    sep_cmd 'ls -dpR /usr/etc/* | column -xc 78'
  fi
  if [ -d /var/log/socklog ] ; then
    cat << EOF
${sep}
(cd /var/log/socklog ; sudo ls -dp */config | column -xc 78)
`(cd /var/log/socklog ; sudo ls -dp */config | column -xc 78)`
EOF
  else
    sep_cmd 'ls -dp /etc/*syslog*.conf /etc/*/*syslog*.conf /etc/logrotate.conf /usr/etc/logrotate.conf' ;
  fi
  #if [ -d /var/log/journal ] ; then
  if command -v journalctl > /dev/null ; then
    sep_cmd 'ls -dp /etc/systemd/*journal*.conf*' ;
  fi
  cat << EOF
${sep}
(cd /var/log ; ls -dp * | column -xc 78)
`(cd /var/log ; ls -dp * | column -xc 78)`
EOF
  if [ -d /var/log/socklog ] ; then
    sep_cmd 'sudo tail -v /var/log/socklog/messages/current' ;
  else
    sep_cmd 'sudo tail -v /var/log/messages /var/log/syslog' ;
  fi
  if command -v journalctl > /dev/null ; then
    sep_cmd 'sudo journalctl --identifier systemd-journald --identifier user --lines 10' ;
  fi

  #sep_cmd "sudo find /boot/{efi,EFI} -iname '*.efi'"
  sep_cmd 'sudo find / -ipath /boot/efi/*/*.efi'
  sep_cmd 'sudo dmesg | grep -ie "command line:"'

  sep_cmd 'ls -ahldp /bin /sbin /lib /usr/bin /usr/sbin /usr/lib'
  sudoers_files=`sudo find /etc /usr/etc /usr/local/etc -type f -name sudoers`
  sudoersd_dirs=`sudo find /etc /usr/etc /usr/local/etc -type d -name sudoers.d`
  sudoers_extras=`sudo find ${sudoersd_dirs} -type f`
  sep_cmd "sudo grep -Hn -e NOPASSWD -e secure_path -e @includedir ${sudoers_files} ${sudoers_extras}"
  sep_cmd 'ls -ld /etc/*ail.rc /usr/etc/*ail.rc /var/mail /var/spool/mail $(sudo which smtpctl mailq sendmail mail)'
  sep_cmd 'ls -l /var/mail/ ; sudo smtpctl show queue || sudo mailq 2>&1'
  sep_cmd 'echo q | sudo mail -u root | head -n5 2>&1'
  sep_cmd 'echo q | sudo mail -u packer | head -n5 2>&1'
  sep_cmd 'sudo cat /etc/anacrontab 2>&1'
  sep_cmd 'sudo cat /etc/crontab 2>&1'
  sep_cmd 'sudo crontab -u root -l 2>&1'
  sep_cmd "sudo crontab -u $(id -un) -l 2>&1"
  #sep_cmd "find /etc/* -maxdepth 0 -name '*cron*' | column -xc 78"
  sep_cmd "sudo ls -dp /etc/*cron* /etc/*cron.d/* /etc/periodic/* /var/spool/*cron | column -xc 78"
  if sudo -i command -v systemctl > /dev/null ; then # systemd
    sep_cmd 'sudo systemctl list-timers' ;
  fi
  sep_cmd "ls -dp /etc/ssh/sshd_config* /etc/ssh/sshd_config*/* /usr/etc/ssh/sshd_config* /usr/etc/ssh/sshd_config*/* | column -xc 78"
  if sudo -i command -v systemctl > /dev/null ; then # systemd
    sep_cmd 'sudo systemctl list-unit-files --type=service' ;
    #sep_cmd 'sudo systemctl list-unit-files --type=service --state=enabled' ;
    #sep_cmd 'sudo systemctl list-units --type=service' ;
    sep_cmd 'sudo systemctl list-units --type=service --state=running' ;
  elif sudo -i command -v rc.d > /dev/null ; then
    sep_cmd 'sudo rc.d list' ;
  elif sudo -i command -v rc-status > /dev/null ; then # openrc
    sep_cmd 'sudo rc-service --list | column -xc 78' ;
    #sep_cmd 'sudo rc-status --all' ;
    #sep_cmd 'sudo rc-status --servicelist' ;
    sep_cmd 'sudo rc-update show' ;
  elif sudo -i command -v sv > /dev/null ; then # runit
    if [ -d /etc/runit/sv ] ; then
      #sep_cmd '(cd /etc/runit/sv ; ls -dp * | column -xc 78)' ;
      cat << EOF
${sep}
(cd /etc/runit/sv ; ls -dp * | column -xc 78)
`(cd /etc/runit/sv ; ls -dp * | column -xc 78)`
EOF
    elif [ -d /etc/sv ] ; then
      #sep_cmd '(cd /etc/sv ; ls -dp * | column -xc 78)' ;
      cat << EOF
${sep}
(cd /etc/sv ; ls -dp * | column -xc 78)
`(cd /etc/sv ; ls -dp * | column -xc 78)`
EOF
    fi ;
    if [ -d /run/runit/service ] ; then
      sep_cmd 'sudo sv status /run/runit/service/*' ;
    elif [ -d /etc/service ] ; then
      sep_cmd 'sudo sv status /etc/service/*' ;
    elif [ -d /var/service ] ; then
      sep_cmd 'sudo sv status /var/service/*' ;
    fi ;
  elif sudo -i command -v s6-rc > /dev/null ; then # s6
    sep_cmd 'sudo s6-rc list' ;
    sep_cmd 'sudo s6-rc -a list' ;
  else # sysvinit
    if sudo -i command -v chkconfig > /dev/null ; then
      sep_cmd 'sudo chkconfig --list' ;
    else
      sep_cmd 'sudo service --status-all 2>&1 | column -xc 78' ;
    fi ;
  fi
  if sudo -i command -v ipset > /dev/null ; then
    sep_cmd 'sudo ipset version' ; #sep_cmd 'sudo ipset list' ;
  fi
  if sudo -i command -v firewall-cmd > /dev/null ; then
    sep_cmd 'sudo firewall-cmd -V' ;
    #sep_cmd 'sudo firewall-cmd --zone=public --list-all' ;
  elif sudo -i command -v nft > /dev/null ; then
    sep_cmd 'sudo nft -V' ; #sep_cmd 'sudo nft list ruleset' ;
  elif (sudo -i command -v iptables-nft || sudo -i command -v iptables) > /dev/null ; then
    sep_cmd 'sudo iptables-nft -V || sudo iptables -V' ;
    #sep_cmd 'sudo iptables-nft -L || sudo iptables -L' ;
  elif sudo -i command -v ufw > /dev/null ; then
    sep_cmd 'sudo ufw --version' ; #sep_cmd 'sudo ufw show user-rules' ;
  elif sudo -i command -v shorewall > /dev/null ; then
    sep_cmd 'sudo shorewall version' ; #sep_cmd 'sudo shorewall show -l' ;
  fi
  sep_cmd 'grep -e hosts /etc/nsswitch.conf /usr/etc/nsswitch.conf'

  sep_cmd "ls -dp /etc/ntp*.conf /etc/chrony.conf"
  if sudo -i command -v timedatectl > /dev/null ; then
    sep_cmd 'timedatectl timesync-status || timedatectl' ;
  elif sudo -i command -v chronyc > /dev/null ; then
    sep_cmd 'sudo chronyc -N sources' ;
  elif sudo -i command -v ntpctl > /dev/null ; then
    sep_cmd 'sudo ntpctl -s peers' ;
  else
    sep_cmd 'sudo ntpq --peers || sudo ntpq -p' ;
  fi
  sep_cmd 'date -u' ; sep_cmd 'sudo hwclock -r'
  sep_cmd 'locale | column -xc 78'
  cat << EOF
${sep}
sudo ip -o link show | sed 's|^\([[:digit:]]*:.*>\).*|\1|'
$(sudo ip -o link show | sed 's|^\([[:digit:]]*:.*>\).*|\1|')
EOF
  ifdevs=$(ip -o link | grep 'link/ether' | sed -n 's|\S*: \(\w*\):.*|\1|p')
  cat << EOF
${sep}
ip addr(s):
EOF
  for ifdev in ${ifdevs} ; do
    cat << EOF
${sep}
sudo ip addr show ${ifdev} | sed -n '/inet/ s|.*\(inet\S*\s*\S*\).*|\1|p'
$(sudo ip addr show ${ifdev} | sed -n '/inet/ s|.*\(inet\S*\s*\S*\).*|\1|p')
EOF
  done
  sep_cmd 'hostname -f || hostname' ; sep_cmd 'domainname'
  for file in /etc/hostname /etc/hosts /etc/resolv.conf ; do
    if [ -f "${file}" ] ; then sep_cmd "grep -e '^[^# ]' ${file}" ; fi ;
  done
  if [ -e "/etc/network" ] ; then
    sep_cmd "ls -dp /etc/network/interfaces* /etc/network/interfaces.d/*" ;
  fi
  if [ -e "/etc/sysconfig/network*" ] ; then
    sep_cmd "ls -dp /etc/sysconfig/network* /etc/sysconfig/network*/*" ;
  fi
  sep_cmd 'ls -l /etc/machine-id /var/lib/dbus/machine-id /etc/hostid'
  pkg_repos_sources
  hddev=$(lsblk -nlpo name,label,partlabel | sed -n '/ESP/ s|.*\(/dev/[sv][a-z]*\)[0-9]*.*|\1|p')
  if sudo -i command -v sgdisk > /dev/null ; then
    sep_cmd 'sudo sgdisk -V | head -n1'
    sep_cmd "sudo sgdisk --print ${hddev:-/dev/sda}" ;
  elif sudo -i command -v sfdisk > /dev/null ; then
    sep_cmd 'sudo sfdisk -v | head -n1'
    sep_cmd "sudo sfdisk --list ${hddev:-/dev/sda}" ;
  elif sudo -i command -v parted > /dev/null ; then
    sep_cmd 'sudo parted -v | head -n1'
    #sep_cmd "sudo parted -s ${hddev:-/dev/sda} unit GiB print"
  fi
  #sep_cmd "sudo partx --verbose --show ${hddev:-/dev/sda}"

  sep_cmd 'lsblk'
  sep_cmd 'lsblk -nlpo partlabel | column -xc 78'
  sep_cmd 'lsblk -nlpo label | column -xc 78'

  if [ -e /usr/lib/modules ] ; then
    kver=$(ls -A /usr/lib/modules/ | tail -1)
  else
    kver=$(ls -A /lib/modules/ | tail -1)
  fi
  printf "${sep}\nkver: ${kver} ; uname -r: $(uname -r)\n"
  if sudo -i command -v akms > /dev/null ; then
    sep_cmd "sudo akms status -k ${kver}"
  elif sudo -i command -v dkms > /dev/null ; then
    sep_cmd "sudo dkms status -k ${kver}"
  fi
  #if sudo -i command -v zfs > /dev/null ; then
  if [ -n "`df -lhT / | grep -e zfs`" ] ; then
    zfs_ver=$(sudo zfs version | head -n1 | sed 's|zfs-||') ;
    printf "${sep}\nZFS info (${zfs_ver})\n" ;
    sep_cmd 'sudo zfs version' ; sep_cmd 'sudo zpool list -v' ;
    sep_cmd 'sudo zfs list -t all' ;
  #elif sudo -i command -v btrfs > /dev/null ; then
  elif [ -n "`df -lhT / | grep -e btrfs`" ] ; then
    printf "${sep}\nBtrfs info\n" ;
    sep_cmd 'sudo modinfo btrfs | grep -e name -e version -e vermagic'
    sep_cmd 'sudo btrfs filesystem show' ;
    sep_cmd 'sudo btrfs subvolume list /' ;
  #elif sudo -i command -v lvm > /dev/null ; then
  elif [ -n "`lsblk | grep -e '/[ ]*$' | grep -e lvm`" ] ; then
    printf "${sep}\nLVM info\n" ;
    sep_cmd 'sudo lvm version' ;
    sep_cmd 'sudo pvs' ; sep_cmd 'sudo vgs' ;
    sep_cmd 'sudo lvs -o vg_name,lv_name,lv_attr,lv_size' ;
  fi
  for file in /etc/crypttab /etc/fstab /etc/fstab.* ; do
    if [ -f "${file}" ] ; then sep_cmd "sudo grep -e '^[^# ]' ${file}" ; fi ;
  done
  sep_cmd 'df -lhT --total || df -lhT || df -lh'
  sep_cmd 'du -hd 1 / 2> /dev/null | column -xc 78'

  #sep_cmd 'ls -dp /home/* | column -xc 78'
  cat << EOF
${sep}
(cd /home ; ls -dp * | column -xc 78)
`(cd /home ; ls -dp * | column -xc 78)`
EOF
  #sep_cmd "(ls -dp /home/$(id -un)/* || ls -dp /home/packer/*) | column -xc 78"
  if [ -d "/home/$(id -un)" ] ; then
    cat << EOF
${sep}
(cd /home/$(id -un) ; ls -d -- .??*/ */ | column -xc 78)
`(cd /home/$(id -un) ; ls -d -- .??*/ */ | column -xc 78)`
EOF
  else
    cat << EOF
${sep}
(cd /home/packer ; ls -d -- .??*/ */ | column -xc 78)
`(cd /home/packer ; ls -d -- .??*/ */ | column -xc 78)`
EOF
  fi
  sep_cmd 'id'

  cat << EOF
${sep}
TERM: ${TERM} ; SHELL: ${SHELL} ; LANG: ${LANG}
${sep}
PATH: ${PATH}
EOF
  sep_cmd 'lpstat -s'
  cat << EOF
${sep}
/home/$(id -un)/[.xsession|.xinitrc]
EOF
  if [ -e "/home/$(id -un)/.xsession" ] ; then
    sep_content "/home/$(id -un)/.xsession" ;
  elif [ -e "/home/$(id -un)/.xinitrc" ] ; then
    sep_content "/home/$(id -un)/.xinitrc" ;
  else
    echo ${sep} ;
  fi
}

macos_info() {
  echo "(${NAME} ${MACHINE})" 'collect_info'
  sep_cmd 'uname -a' ; sep_cmd 'sw_vers'
  sep_cmd 'free -h' ; sep_cmd 'top -l 1 -n 1 -pid 0'
  sep_cmd 'sysctl machdep.cpu.brand_string'
  sep_cmd 'system_profiler SPDisplaysDataType'
  sep_cmd 'system_profiler SPSoftwareDataType'

  sep_cmd 'system_profiler SPHardwareDataType | grep -ve ID -ve Serial'
  sep_cmd "ls -dp /etc/ssh/sshd_config* /etc/ssh/sshd_config*/* | column -xc 78"

  sep_cmd 'date'
  cat << EOF
${sep}
ifconfig | grep -Ee '^[[:alnum:]]*:.*> metric .*' | sed 's|^\(.*>\).*|\1|'
$(ifconfig | grep -Ee '^[[:alnum:]]*:.*> metric .*' | sed 's|^\(.*>\).*|\1|')
EOF
  ifdev=$(ifconfig | grep '^[a-z]' | grep -e en0 | cut -d: -f1 | head -n1)
  cat << EOF
${sep}
ip addr(s):
EOF
  sep_cmd "ifconfig ${ifdev} | grep -e 'inet ' | cut -d' ' -f1-2"
  sep_cmd 'hostname' ; sep_cmd 'domainname'
  sep_cmd "grep -e '^[^# ]' /etc/hosts"

  sep_cmd 'diskutil coreStorage list' ; sep_cmd 'diskutil list'
  sep_cmd 'df -lh' ; sep_cmd 'du -hd 1 / 2> /dev/null | column -xc 78'

  #sep_cmd 'ls -dp /Users/* | column -xc 78'
  cat << EOF
${sep}
(cd /Users ; ls -dp * | column -xc 78)
`(cd /Users ; ls -dp * | column -xc 78)`
EOF
  #sep_cmd "(ls -dp /Users/$(id -un)/* || ls -dp /Users/packer/*) | column -xc 78"
  if [ -d "/Users/$(id -un)" ] ; then
    cat << EOF
${sep}
(cd /Users/$(id -un) ; ls -d -- .??*/ */ | column -xc 78)
`(cd /Users/$(id -un) ; ls -d -- .??*/ */ | column -xc 78)`
EOF
  else
    cat << EOF
${sep}
(cd /Users/packer ; ls -d -- .??*/ */ | column -xc 78)
`(cd /Users/packer ; ls -d -- .??*/ */ | column -xc 78)`
EOF
  fi
  sep_cmd 'id'

  cat << EOF
${sep}
TERM: ${TERM} ; SHELL: ${SHELL} ; LANG: ${LANG}
${sep}
PATH: ${PATH}
EOF
  sep_cmd 'lpstat -s'
}

collect_all() {
  tarext=${tarext:-} ; tarcmd=${tarcmd:-tar} # ? BSDs more features: gtar
  if [ "OpenBSD" = "${OS_NAME}" ] ; then tarcmd=gtar ; fi

  case ${OS_NAME} in
    'Darwin')
      #msgfile="msg5-${MACHINE}.txt" ; lang_devel_versions > ${msgfile} ;
      msgfile="msg4-${MACHINE}.txt" ; echo "(${NAME} ${MACHINE})" 'desktop applications' > ${msgfile} ;
      ls -p /Applications | column -xc 78 >> ${msgfile} ;
      msgfile="msg2-${MACHINE}.txt" ; echo "(${NAME} ${MACHINE})" 'leaf_pkgs' > ${msgfile} ;
      (sep_cmd 'port installed requested | column -xc 78' ;
      echo "==================") >> ${msgfile} ;
      (sep_cmd 'brew leaves | column -xc 78' ;
      echo '#cask #git-cola #pyqt #python@3.11 #sshfs #transmission-cli' | tr ' ' '\n' | column -xc 78 ;
      sep_cmd 'brew list --cask | column -xc 78' ;
      echo '#adobe-acrobat-reader #amazon-music #db-browser-for-sqlite #fbreader #foxitreader #gitkraken #gnucash #gramps #kindle #libreoffice-still #osxfuse #rsyncosx #transmission #ytmdesktop-youtube-music ##airdroid ##avg-antivirus ##android-sdk ##android-studio ##audioscrobbler ##duckduckgo ##geogebra ##icefloor ##intellij-idea ##macdroid ##murus ##tigervnc-viewer ##smart-zipper-pro ##textedit' | tr ' ' '\n' | column -xc 78 ;
      #sep_cmd 'brew list --formula | column -xc 78' ;
      #echo '#cask #git-cola #pyqt #python@3.11 #python@3.12 #sshfs #transmission-cli' | tr ' ' '\n' | colmun -xc 78 ;
      echo "==================") >> ${msgfile} ;
      (sep_cmd 'python3 --version || python --version' ;
      sep_cmd '(python3 -m pip list --not-required --format freeze || python -m pip list --not-required --format freeze) | column -xc 78') >> ${msgfile} ;

      msgfile="msg1-${MACHINE}.txt" ; macos_info | cat > ${msgfile} ;;
  'FreeBSD'|'OpenBSD'|'NetBSD'|'Linux')
      #msgfile="msg5-${MACHINE}.txt" ; lang_devel_versions > ${msgfile} ;
      msgfile="msg4-${MACHINE}.txt" ; echo "(${NAME} ${MACHINE})" 'desktop applications' > ${msgfile} ;
      if [ -e /usr/local/share/applications ] ; then
        ls /usr/local/share/applications | column -xc 78 >> ${msgfile} ;
      elif [ -e /usr/share/applications ] ; then
        ls /usr/share/applications | column -xc 78 >> ${msgfile} ;
      fi ;
      msgfile="msg3-${MACHINE}.txt" ; echo "(${NAME} ${MACHINE})" 'explicit_pkgs' > ${msgfile} ;
      pkgs_installed explicit >> ${msgfile} ;
      echo "==================" >> ${msgfile} ;
      (sep_cmd 'python3 --version || python --version' ;
      sep_cmd '(python3 -m pip list --not-required --format freeze || python -m pip list --not-required --format freeze) | column -xc 78') >> ${msgfile} ;
      msgfile="msg2-${MACHINE}.txt" ; echo "(${NAME} ${MACHINE})" 'leaf_pkgs' > ${msgfile} ;
      pkgs_installed leaf >> ${msgfile} ;

      msgfile="msg1-${MACHINE}.txt" ;
      if [ "Linux" = "${OS_NAME}" ] ; then
        linux_info | cat > ${msgfile} ;
      else
        bsd_info | cat > ${msgfile} ;
      fi ;;
    *) echo 'ERROR: OS is not Linux | [Free | Open | Net]BSD | Darwin(MacOS)' ;
      echo '...exiting...' ; exit ;;
  esac

  for archive_cmd in ${tarcmd} "zip" "7za" ; do
    if command -v ${archive_cmd} > /dev/null ; then
      case ${archive_cmd} in
        'tar'|'gtar') ${tarcmd} -caf info.tar${tarext} msg*.txt ;;
        'zip') zip -r info.zip msg*.txt ;;
        '7za') 7za a info.7z msg*.txt ;;
        *) echo 'ERROR: archive cmd is not [g]tar | zip | 7za' ;
          echo '...exiting...' ; exit ;;
      esac ;
    fi ;
  done
  if [ -f info.tar${tarext} ] ; then cp -a info.tar${tarext} /var/tmp/ ; fi
}

#===========================================================================#

${@}
