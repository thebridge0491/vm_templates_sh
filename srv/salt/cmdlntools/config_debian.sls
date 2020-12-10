{% from tpldir ~ "/map.jinja" import varsdict with context %}

Config apt-get no install recommends:
  cmd.run:
    #- shell: /bin/sh
    - name: |
        apt-config dump | grep -we Recommends -e Suggests | sed 's|1|0|' | \
          tee /etc/apt/apt.conf.d/999norecommends

/etc/bash.bashrc:
  file.replace:
    - pattern: '^export JAVA_HOME.*'
    - repl: 'export JAVA_HOME={{varsdict.distro_pkgs.default_java_home}}'
    - append_if_not_found: True

{{varsdict.distro_pkgs.default_java_home}}:
  file.directory

{{varsdict.distro_pkgs.default_java_home.replace('"', '')+'/release'}}:
  file.replace:
    - pattern: '^JAVA_VERSION.*'
    - repl: 'JAVA_VERSION={{varsdict.distro_pkgs.default_java_version}}'
    - append_if_not_found: True

# #NOTE, nftables lacking sysvinit support
{% for item in {'rexp': '^#!/bin/sh.*', 'line': '#!/bin/sh'},
   {'rexp': '.*/sbin/nft.*', 'line': '/sbin/nft -f /etc/nftables.conf'} %}
'Change {{item.rexp}} to {{item.line}}':
  file.replace:
    - name: '/etc/network/if-pre-up.d/nftables'
    - pattern: '{{item.rexp}}'
    - repl: '{{item.line}}'
    - append_if_not_found: True
{% endfor %}

Config misc services(firewall):
  cmd.run:
    #- shell: /bin/sh
    - name: |
        #ntpd -u ntp:ntp ; ntpq -p ; sleep 3
        ##cp /usr/share/doc/nftables/examples/sysvinit/nftables.init /etc/init.d/nftables ; chmod +x /etc/init.d/nftables
        ##ufw disable
        #sh /root/init/common/linux/firewall/ufw/config_ufw.sh cmds_ufw allow
        sh /root/init/common/linux/firewall/nftables/config_nftables.sh config_nftables allow
        #ufw allow in svc MDNS

/etc/sudoers:
  file.line:
    - after: 'Defaults.*env_reset.*'
    - mode: ensure
    - match: 'Defaults.*secure_path=.*'
    - content: 'Defaults    secure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"'
