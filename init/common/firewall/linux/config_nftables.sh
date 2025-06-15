#!/bin/sh

SCRIPTPARENT=${SCRIPTPARENT:-$(dirname ${0})}

config_nftables() {
  policy_out=${1:-allow} # allow | deny
  tar -xf ${SCRIPTPARENT}/rules_nftables.tar.gz -C /etc

  . /etc/os-release
  if [ ! -e /etc/os-release ] && [ -f /usr/lib/os-release ] ; then
    . /usr/lib/os-release ;
  fi

  cp -an /etc/nftables.conf /etc/nftables.conf.orig
  cp -a /etc/nftables.conf.orig /etc/nftables.conf
  if [ "alpine" = "${ID}" ] ; then
    nft -f /etc/nftables/cmds_nftables_out${policy_out}.ruleset ;
    nft list ruleset > /etc/nftables.conf.new ;
  else
    nft flush ruleset ; #nft flush table inet filter ;
    cp /etc/nftables/out${policy_out}_nftables.conf /etc/nftables.conf.new ;
  fi
  #cp -b --suffix '.orig' /etc/nftables.conf.new /etc/nftables.conf
  cp -n /etc/nftables.conf.new /etc/nftables.conf
  # ##########
  #diff -s /etc/nftables.conf /etc/nftables.conf.new
  ##(sleep 120 && nft flush ruleset)& && nft -f /etc/nftables.conf
  #nft -f /etc/nftables.conf

  #if [ -z "$(grep -e 'domain.*mdns' /etc/nftables.conf /etc/nftables/out*_nftables.conf)" ] ; then
  #  #nft add rule inet filter in_allow udp port { domain, mdns } accept ;
  #  sed -i 's|domain|domain, mdns|g' /etc/nftables.conf \
  #    /etc/nftables/out*_nftables.conf ;
  #fi
  #nft list tables ; sleep 5 ; nft list ruleset ; sleep 5
}

#===========================================================
${@:-config_nftables allow}
