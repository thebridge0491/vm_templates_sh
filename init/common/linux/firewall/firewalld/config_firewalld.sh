#!/bin/sh

_cmds_firewalld_outallow() {
	zone=${1:-public}
	firewall-offline-cmd  --set-default-zone=${zone}
	#firewall-offline-cmd --zone=${zone} --add-port=22/tcp
	#firewall-offline-cmd --zone=${zone} --direct --add-rule ipv4 filter INPUT 4 -p tcp --dport ssh -m conntrack --ctstate NEW -m limit --limit 3/min --limit-burst 5 -j LOG --log-prefix "[FW LIMIT ]"
	firewall-offline-cmd --zone=${zone} --add-rich-rule 'rule service name="ssh" log prefix="[FW LIMIT] " limit value="3/m" accept'
	firewall-offline-cmd --zone=${zone} --add-service=dns
	firewall-offline-cmd --zone=${zone} --add-port=auth/tcp

	#firewall-offline-cmd --new-ipset=lanpvt_v6 --type=hash:net --option=family=inet6
	firewall-offline-cmd --new-ipset=lanpvt_v4 --type=hash:net
	for netw in 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16 ; do
		firewall-offline-cmd --ipset=lanpvt_v4 --add-entry=${netw} ;
	done
	#firewall-offline-cmd --zone=${zone} --add-rich-rule 'rule family="ipv4" source ipset="lanpvt_v4" log prefix="[FW BLOCK] " reject type="icmp-port-unreachable"'
	#firewall-offline-cmd --zone=${zone} --add-rich-rule 'rule family="ipv6" source address="fd00::/8" log prefix="[FW BLOCK] " reject type="icmp6-port-unreachable"'
}

_cmds_firewalld_outdeny() {
	zone=${1:-block}
	_cmds_firewalld_outallow ${zone}
	firewall-offline-cmd  --set-default-zone=${zone}

	#firewall-offline-cmd --zone=${zone} --direct --add-rule ipv4 filter \
	#	OUTPUT 10 -j REJECT --reject-with icmp-port-unreachable	# tcp-reset ?
	#firewall-offline-cmd --zone=${zone} --direct --add-rule ipv6 filter \
	#	OUTPUT 10 -j REJECT --reject-with icmp6-port-unreachable

	#ufw allow out domain #comment \'allow out svc DNS\'
	#ufw allow out ntp #comment \'allow out svc NTP\'
	#ufw allow out auth/tcp #comment \'allow out svc Auth\'
}

cmds_firewalld() {
	policy_out=${1:-allow} # allow | deny
	firewalld --debug=5
	firewall-offline-cmd --set-log-denied=all   # Red Hat/CentOS 7.3+

	_cmds_firewalld_out${policy_out}
	firewall-cmd --reload
	firewall-cmd --get-active-zones ; sleep 5 ; ipset list ; sleep 5
	firewall-cmd --state ; sleep 5
	firewall-cmd --list-all --zone=public ; sleep 5
	firewall-cmd --list-all --zone=block ; sleep 5
}

#===========================================================
${@}
