#!/bin/sh

SCRIPTPARENT=${SCRIPTPARENT:-$(dirname ${0})}

if [ 'FreeBSD' = "$(uname -s)" ] ; then
  sed_inplace=${sed_inplace:-"sed -i ''"} ;
else
  sed_inplace=${sed_inplace:-"sed -i"} ;
fi

config_pf() {
  policy_out=${1:-allow} # allow | deny
  ifc0=${2:-$(ifconfig | grep '^[a-z]' | grep -ve lo0 | cut -d: -f1 | head -n 1)}
  cd /tmp ; tar -xzf ${SCRIPTPARENT}/rules_pf.tar.gz -C /etc

  cp -an /etc/pf.conf /etc/pf.conf.orig ; cp -a /etc/pf.conf.orig /etc/pf.conf
  /sbin/pfctl -d
  if [ -z "$(grep -e 'domain.*mdns' /etc/pf/outallow_in_allow.rules)" ] ; then
    #echo 'pass in proto udp from any to any port { domain, mdns } keep state' >> /etc/pf/outallow_in_allow.rules ;
    ${sed_inplace} 's|domain|domain, mdns|g' /etc/pf/outallow_in_allow.rules ;
  fi
  #if [ 'NetBSD' = "$(uname -s)" ] ; then
  #  ${sed_inplace} '/icmp6 / s|icmp6 |ipv6-icmp |' /etc/pf/outallow_in_allow.rules \
  #    /etc/pf/outdeny_out_allow.rules ;
  #fi
  for rules_file in $(find /etc/pf -name "*.rules") ; do
    ${sed_inplace} "s|^ext_ifc.*$|ext_ifc = \"${ifc0}\"|" ${rules_file} ;
    if [ 'NetBSD' = "$(uname -s)" ] ; then
      ${sed_inplace} '/icmp6 / s|icmp6 |ipv6-icmp |' ${rules_file} ;
    fi ;
  done
  if [ 'OpenBSD' = "$(uname -s)" ] ; then
    scrub_line='match in all scrub (no-df random-id max-mss 1440)' ;
  else # FreeBSD, NetBSD
    scrub_line='scrub in all fragment reassemble no-df max-mss 1440' ;
  fi
  cat << EOF > /etc/pf.conf.new
#ext_ifc = "${ifc0}"

# block policy: drop - silently ; return - send rejections
set block-policy return

# allow loopback iface traffic unfiltered
set skip on lo0

${scrub_line}
block all label 'policy deny incoming, deny outgoing'

anchor "dir_action"
anchor "dir_action/*"

load anchor "dir_action" from "/etc/pf/out${policy_out}_dir_action.rules"

EOF
  cp -n /etc/pf.conf.new /etc/pf.conf
  /sbin/pfctl -vf /etc/pf.conf
  # ##########
  #diff -s /etc/pf.conf /etc/pf.conf.new
  ##(sleep 120 && /sbin/pfctl -d)& && /sbin/pfctl -e
  #/sbin/pfctl -e

  #if [ -z "$(grep -e 'domain.*mdns' /etc/pf/outallow_in_allow.rules)" ] ; then
  #  #echo 'pass in proto udp from any to any port { domain, mdns } keep state' >> /etc/pf/outallow_in_allow.rules ;
  #  ${sed_inplace} 's|domain|domain, mdns|g' /etc/pf/outallow_in_allow.rules ;
  #fi
  #/sbin/pfctl -s info ; sleep 5 #; /sbin/pfctl -s rules -a '*' ; sleep 5
}

#===========================================================
${@:-config_pf allow}
