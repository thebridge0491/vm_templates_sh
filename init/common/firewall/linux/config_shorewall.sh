#!/bin/sh

SCRIPTPARENT=${SCRIPTPARENT:-$(dirname ${0})}

_config_ipset() {
  ipset flush ; ipset destroy
  cp -an /etc/ipset.conf /etc/ipset.conf.orig
  cp -a /etc/ipset.conf.orig /etc/ipset.conf

  ipset restore -file /etc/ipset.conf
  ipset create lanpvt_v4 hash:net
  ipset create lanpvt_v6 hash:net family inet6
  for svc_grp in tcp_log_svcs udp_log_svcs tcp_svcs udp_svcs ; do
    ipset create ${svc_grp} bitmap:port range 0-1024 ;
  done
  ipset add lanpvt_v6 fd00::/8
  for netw in 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16 ; do
    ipset add lanpvt_v4 ${netw} ;
  done
  ipset add tcp_log_svcs ssh
  for svc in domain auth ; do
    ipset add tcp_svcs ${svc} ;
  done
  for svc in domain mdns ; do
    ipset add udp_svcs ${svc} ;
  done
  ipset save > /etc/ipset.conf.new
  #cp -b --suffix '.orig' /etc/ipset.conf.new /etc/ipset.conf
  cp -n /etc/ipset.conf.new /etc/ipset.conf
  ipset restore -file /etc/ipset.conf
  #diff -s /etc/ipset.conf /etc/ipset.conf.new
}

config_shorewall() {
  policy_out=${1:-allow} # allow | deny
  tar -xf ${SCRIPTPARENT}/rules_iptables.tar.gz -C /etc

  _config_ipset
  iptables-nft -F ; iptables-nft -X ; ip6tables-nft -F ; ip6tables-nft -X
  shorewall clear ; shorewall6 clear

  for ruleset in iptables.rules ip6tables.rules ; do
    cp -an /etc/iptables/${ruleset} /etc/iptables/${ruleset}.orig ;
    cp -a /etc/iptables/${ruleset}.orig /etc/iptables/${ruleset} ;
    cp /etc/iptables/out${policy_out}_ipXtables.rules /etc/iptables/${ruleset}.new ;
    cp -n /etc/iptables/${ruleset}.new /etc/iptables/${ruleset} ;
  done
  # ##########
  #for ruleset in iptables.rules ip6tables.rules ; do
  #  diff -s /etc/iptables/${ruleset} /etc/iptables/${ruleset}.new ;
  #done
  #(sleep 120 && (iptables-nft -F ; iptables-nft -X ; ip6tables-nft -F ; \
  #  ip6tables-nft -X))& \
  #  (iptables-nft-restore /etc/iptables/iptables.rules ; \
  #  ip6tables-nft-restore /etc/iptables/ip6tables.rules)

  #if [ -z "$(grep -e 'domain.*mdns' /etc/ipset.conf)" ] ; then
  #  #ip[6]tables-nft -A In_allow -p udp -m multiport --dports domain,mdns -j ACCEPT ;
  #  sed -i 's|domain|domain,mdns|g' /etc/ipset.conf ;
  #fi
  #ipset list ; sleep 5
  #iptables-nft -L ; sleep 5 #; ip6tables-nft -L ; sleep 5
  #shorewall show -l ; sleep 5 #; shorewall6 show -l ; sleep 5
}

#===========================================================
${@:-config_shorewall allow}
