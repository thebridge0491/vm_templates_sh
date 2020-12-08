#!/bin/sh

cmds_SuSEfirewall2() {
	FW_CONFIG=${1:-"/etc/sysconfig/SuSEfirewall2"}
	yast firewall disable
	yast firewall logging set accepted=crit nonaccepted=crit logbroadcast=yes \
		zone=EXT
	sed -i 's|\(FW_LOG_LIMIT=\)".*$|\1\"3\/minute\"|' "$FW_CONFIG"
	sed -i 's|\(FW_REJECT=\)".*$|\1\"yes\"|' "$FW_CONFIG"
	#yast firewall services add tcpport=ssh zone=EXT
	#sed -i 's|\(FW_SERVICES_EXT_TCP=\)"\(.*\)"|\1"\2 ssh"|' "$FW_CONFIG"
	sed -i "s|\(FW_SERVICES_ACCEPT_EXT=\)\"\(.*\)$|\1\"0\/0,tcp,22,,hitcount=3,blockseconds=60,recentname=ssh\2|" "$FW_CONFIG"
	yast firewall services add tcpport=domain udpport=domain zone=EXT
	yast firewall services add tcpport=auth zone=EXT
	#nets_reject='10.0.0.0\/8,tcp\n10.0.0.0\/8,udp\n172.16.0.0\/12,tcp\n172.16.0.0\/12,udp\n192.168.0.0\/16,tcp\n192.168.0.0\/16,udp\nfd00::\/8,tcp\nfd00::\/8,udp\n'
	#sed -i "s|\(FW_SERVICES_REJECT_EXT=\)\"\(.*\)$|\1\"${nets_reject}\2|" "$FW_CONFIG"
	yast firewall enable ; yast firewall services show ; sleep 5
}

#===========================================================
$@
