#!/bin/sh

config_nftables() {
	policy_out=${1:-allow} # allow | deny
	tar -xf /root/firewall/nftables/nftables_conf.tar.gz -C /etc
	
	#nft flush table inet filter
	nft flush ruleset
	
	#cp -b --suffix '.old' /etc/nftables/out${policy_out}_nftables.conf /etc/nftables.conf
	cp /etc/nftables.conf /etc/nftables.conf.old
	cp /etc/nftables/out${policy_out}_nftables.conf /etc/nftables.conf
	
	nft list tables ; sleep 5 ; nft list ruleset ; sleep 5
}

cmds_nftables() {
	policy_out=${1:-allow} # allow | deny
	tar -xf /root/firewall/nftables/nftables_conf.tar.gz -C /etc
	
	nft -f /etc/nftables/cmds_nftables_out${policy_out}.ruleset
	
	nft list ruleset > /tmp/out${policy_out}_nftables.conf
	
	#cp -b --suffix '.old' /tmp/out${policy_out}_nftables.conf /etc/nftables.conf
	cp /etc/nftables.conf /etc/nftables.conf.old
	cp /tmp/out${policy_out}_nftables.conf /etc/nftables.conf
	
	nft list tables ; sleep 5 ; nft list ruleset ; sleep 5
}

#===========================================================
$@
