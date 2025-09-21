{% if varsdict.firewall_tool == 'pf' and grains['kernel']|lower in ['freebsd', 'netbsd', 'openbsd'] %}
Config firewall pf:
  cmd.run:
    #- shell: /bin/sh
    - name: |
        sh /root/init/common/firewall/bsd/config_pf.sh #config_pf allow
        #diff -s /etc/pf.conf /etc/pf.conf.new ; sleep 5

Enable firewall pf:
  cmd.run:
    #- shell: /bin/sh
    - name: |
        #(sleep 120 && /sbin/pfctl -d)& && /sbin/pfctl -e
        /sbin/pfctl -e

/etc/pf/outallow_in_allow.rules:
  file.replace:
    - pattern: '^(.*)domain(.*)mdns(.*)$'
    - repl: '\1domain\2, mdns\3'

Display firewall info:
  cmd.run:
    #- shell: /bin/sh
    - name: /sbin/pfctl -s info ; sleep 5 #; /sbin/pfctl -s rules -a '*' ; sleep 5
{% endif %}

{% if varsdict.firewall_tool == 'ufw' and grains['kernel']|lower in ['linux'] %}
Config firewall ufw:
  cmd.run:
    #- shell: /bin/sh
    - name: |
        sh /root/init/common/firewall/linux/config_ufw.sh #cmds_ufw allow

Enable firewall ufw & allow mdns traffic:
  cmd.run:
    #- shell: /bin/sh
    - name: |
        #(sleep 120 && ufw disable)& && ufw enable
        ufw enable
        ufw allow in svc MDNS

Display firewall info:
  cmd.run:
    #- shell: /bin/sh
    - name: ufw status ; sleep 5 ; ufw show user-rules ; sleep 5
{% endif %}

{% if varsdict.firewall_tool in ['iptables', 'iptables-nft'] and grains['kernel']|lower in ['linux'] %}
Config firewall iptables[-nft]:
  cmd.run:
    #- shell: /bin/sh
    - name: |
        #drakfirewall ; sleep 600
        sh /root/init/common/firewall/linux/config_iptables.sh #config_iptables allow
        #for ruleset in iptables.rules ip6tables.rules ; do
        #  diff -s /etc/iptables/${ruleset} /etc/iptables/${ruleset}.new ;
        #done

Enable firewall iptables[-nft]:
  cmd.run:
    #- shell: /bin/sh
    - name: |
        #(sleep 120 && (iptables-nft -F ; iptables-nft -X ; ip6tables-nft -F ; \
        #  ip6tables-nft -X))& && \
        #  (iptables-nft-restore /etc/iptables/iptables.rules ; \
        #  ip6tables-nft-restore /etc/iptables/ip6tables.rules)
        (iptables-nft-restore /etc/iptables/iptables.rules ;
          ip6tables-nft-restore /etc/iptables/ip6tables.rules)

/etc/ipset.conf:
  file.replace:
    - pattern: '^(.*)domain(.*)mdns(.*)$'
    - repl: '\1domain\2, mdns\3'

Display firewall info:
  cmd.run:
    #- shell: /bin/sh
    - name: |
        #ipset list ; sleep 5
        iptables-nft -L ; sleep 5 ; ip6tables-nft -L ; sleep 5
{% endif %}

{% if varsdict.firewall_tool == 'nftables' and grains['kernel']|lower in ['linux'] %}
Config firewall nftables:
  cmd.run:
    #- shell: /bin/sh
    - name: |
        sh /root/init/common/firewall/linux/config_nftables.sh #config_nftables allow
        #diff -s /etc/nftables.conf /etc/nftables.conf.new

Enable firewall nftables:
  cmd.run:
    #- shell: /bin/sh
    - name: |
        #(sleep 120 && nft flush ruleset)& && nft -f /etc/nftables.conf
        nft -f /etc/nftables.conf

  {# {% set found_confs = salt['file.find']('/etc', name='.*nftables.conf') | default([]) %} #}
  {% set out_confs = salt['cmd.shell']('find /etc -name "[outalwdeny_]*nftables.conf"', shell='/bin/sh').split() %}
  {% for item in out_confs %}
'Allow mdns traffic on firewall {{item}}':
  file.replace:
    - name: {{item}}
    - pattern: '^(.*)domain(.*)mdns(.*)$'
    - repl: '\1domain\2, mdns\3'
  {% endfor %}

Display firewall info:
  cmd.run:
    #- shell: /bin/sh
    - name: nft list tables ; sleep 5 ; nft list ruleset ; sleep 5
{% endif %}

{% if varsdict.firewall_tool == 'firewalld' and grains['kernel']|lower in ['linux'] %}
Config firewall firewalld:
  cmd.run:
    #- shell: /bin/sh
    - name: |
        sh /root/init/common/firewall/linux/config_firewalld.sh #cmds_firewalld allow

Enable firewall firewalld:
  cmd.run:
    #- shell: /bin/sh
    - name: |
        #(sleep 120 && firewall-offline-cmd --disabled)& && \
        #  (firewall-offline-cmd --enabled ; firewall-cmd --reload)
        firewall-offline-cmd --enabled ; firewall-cmd --reload

Allow mdns traffic in firewall public zone:
  firewalld.present:
    - name: public
    - services: ['mdns']

Display firewall info:
  #cmd.run:
  #  #- shell: /bin/sh
  #  - name: |
  #      firewall-cmd --get-active-zones ; sleep 5
  #      #ipset list ; sleep 5
  #      firewall-cmd --state ; sleep 5 ; firewall-cmd --zone=public --list-all ; sleep 5

  module.run:
    - firewalld.list_all
      - zone: public
{% endif %}
