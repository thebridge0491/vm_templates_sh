#!/bin/sh

config_pf() {
	policy_out=${1:-allow} # allow | deny
	ifc0=${2:-$(ifconfig | grep '^[a-z]' | cut -d: -f1 | head -n 1)}
	cd /tmp ; tar -xf /root/firewall/pf/pf_rules.tar.gz -C /etc
	for rules_file in $(find /etc/pf -name "*.rules") ; do
		sed -i '' "s|^ext_ifc.*$|ext_ifc = \"${ifc0}\"|" $rules_file ;
	done
cat << EOF
ext_ifc = "${ifc0}"

# block policy: drop - silently ; return - send rejections
set block-policy return

# allow loopback iface traffic unfiltered
set skip on lo0

scrub in all fragment reassemble no-df max-mss 1440
block all label 'policy deny incoming, deny outgoing'

anchor "dir_action"
anchor "dir_action/*"

load anchor "dir_action" from "/etc/pf/out${policy_out}_dir_action.rules"

EOF
}

#===========================================================
$@
