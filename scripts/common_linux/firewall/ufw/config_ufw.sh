#!/bin/sh

_cmds_ufw_outallow() {
	ufw default deny incoming ; ufw default allow outgoing
	ufw limit in log ssh/tcp #comment \'allow in log svc SSH\'
	ufw allow in domain #comment \'allow in svc DNS\'
	ufw allow in auth/tcp #comment \'allow in svc Auth\'
	
	for netw in 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16 fd00::/8 ; do
		ufw reject in log from $netw ;
	done
}

_cmds_ufw_outdeny() {
	_cmds_ufw_outallow
	ufw default deny outgoing
	ufw allow out domain #comment \'allow out svc DNS\'
	ufw allow out ntp #comment \'allow out svc NTP\'
	ufw allow out auth/tcp #comment \'allow out svc Auth\'
}

cmds_ufw() {
	policy_out=${1:-allow} # allow | deny
	sed -i 's|^ENABLED=.*|ENABLED=yes|' /etc/ufw/ufw.conf
	# 'ufw allow SSH'
	echo 'ufw limit in log ssh/tcp #comment "allow in log svc SSH"' >> \
		/etc/ufw/ufw.conf
	
	_cmds_ufw_out${policy_out}
	ufw logging on	# on|off|low|medium|high|full
	ufw enable ; ufw status ; sleep 5 ; ufw show user-rules ; sleep 5
}

#===========================================================
$@
