#!/bin/sh

_config_ipset() {
	ipset create lanpvt_v4 hash:net
	ipset create lanpvt_v6 hash:net family inet6
	for svc_grp in tcp_log_svcs udp_log_svcs tcp_svcs udp_svcs ; do
		ipset create $svc_grp bitmap:port range 0-1024 ;
	done
	ipset add lanpvt_v6 fd00::/8
	for netw in 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16 ; do
		ipset add lanpvt_v4 $netw ;
	done
	ipset add tcp_log_svcs ssh
	for svc in domain auth ; do
		ipset add tcp_svcs $svc ;
	done
	ipset add udp_svcs domain
	ipset list ; sleep 5 ; ipset save > /tmp/ipset.conf
	#cp -b --suffix='.old' /tmp/ipset.conf /etc/ipset.conf
	cp /etc/ipset.conf /etc/ipset.conf.old
	cp /tmp/ipset.conf /etc/ipset.conf
}

config_iptables() {
	policy_out=${1:-allow} # allow | deny
	tar -xf /root/init/common/linux/firewall/iptables/iptables_rules.tar.gz -C /etc
	
	_config_ipset
	iptables -F ; iptables -X ; ip6tables -F ; ip6tables -X
	
	for ruleset in iptables.rules ip6tables.rules ; do
		cp /etc/iptables/out${policy_out}_ipXtables.rules \
			/etc/iptables/$ruleset ;
	done
	
	iptables -L ; sleep 5 ; ip6tables -L ; sleep 5
}

#===========================================================
$@
