{#{% set distrosets = ["xbase"] %}
{% include 'common/fetch_distrosets.sls' %}#}

{% for item in ['daily', 'weekly', 'monthly'] %}
'/etc/{{item}}.orig':
  file.copy:
    - source: '/etc/{{item}}'
    - force: False
{% endfor %}

disable mail output from /etc/daily:
  file.replace:
    - name: /etc/daily
    - pattern: '^([^#].*mail .*daily insecurity output.*)$'
    - repl: '#\1'

redirect mail output for /etc/daily:
  file.replace:
    - name: /etc/daily
    - pattern: '^([^#].*)mail .*daily output.*$'
    - repl: '\1cat > /tmp/daily.out ; mv /tmp/daily.out $MAINOUT'

disable mail output from /etc/weekly:
  file.replace:
    - name: /etc/weekly
    - pattern: '^([^#].*mail .*weekly output.*)$'
    - repl: '#\1'

disable mail output from /etc/monthly:
  file.replace:
    - name: /etc/monthly
    - pattern: '^([^#].*mail .*monthly output.*)$'
    - repl: '#\1'

Ensure run dbus-uuidgen in /etc/rc.local:
  file.replace:
    - name: /etc/rc.local
    - pattern: '.*dbus-uuidgen.*'
    #- repl: '/usr/local/bin/dbus-uuidgen --ensure=/etc/machine-id'
    - repl: '/usr/local/bin/dbus-uuidgen --ensure'
    - append_if_not_found: True

mdnsd:
  service.enabled

config mdns daemon flags:
  cmd.run:
    #- shell: /bin/sh
    - name: |
        ifdev=$(ifconfig | grep '^[a-z]' | grep -ve lo0 | cut -d: -f1 | head -n1)
        # /etc/rc.conf.local: mdnsd_flags=vio0
        rcctl set mdnsd flags ${ifdev}

'Ensure mdnsctl publish {hostname} in /etc/rc.local':
  file.replace:
    - name: /etc/rc.local
    - pattern: '.*mdnsctl publish.*'
    - repl: '/usr/local/bin/mdnsctl publish $(hostname -s || hostname) ssh tcp 22 "" &'
    - append_if_not_found: True

{#
group cups:
  group.present:
    - name: cups
    - gid: 193
    - system: True

root groupadd cups:
  group.present:
    - gid: 193
    - system: True
    - addusers: [root]

{% for item in ['lp', 'lpq', 'lpr', 'lprm'] %}
'Move original /usr/bin/{{item}} -> /usr/bin/{{item}}.orig':
  file.copy:
    - name: /usr/bin/{{item}}.orig
    - source: /usr/bin/{{item}}
    - force: False

'Remove original /usr/bin/{{item}}':
  file.absent:
    - name: /usr/bin/{{item}}

  {% if grains['kernel']|lower =='netbsd' %}
'Symlink lp* cmds (printing) [/usr/pkg/bin/{{item}} to /usr/bin/{{item}}]':
  file.symlink:
    - name: /usr/bin/{{item}}
    - target: /usr/pkg/bin/{{item}}
  {% elif grains['kernel']|lower in ['freebsd', 'netbsd'] %}
'Symlink lp* cmds (printing) [/usr/local/bin/{{item}} to /usr/bin/{{item}}]':
  file.symlink:
    - name: /usr/bin/{{item}}
    - target: /usr/local/bin/{{item}}
  {% endif %}
{% endfor %}
#}
