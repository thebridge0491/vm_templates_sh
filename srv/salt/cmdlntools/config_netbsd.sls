{#{% set distrosets = ["xbase"] %}
{% include 'common/fetch_distrosets.sls' %}#}

{% for item in ['/var/run/dbus', '/var/db/dbus'] %}
{{item}}:
  file.directory
{% endfor %}

# freshclamd, clamd
{% for item in ['dbus', 'avahidaemon', 'cupsd'] %}
Xfer /usr/pkg/share/examples/rc.d/{{item}} /etc/rc.d/{{item}}:
  cmd.run:
    #- shell: /bin/sh
    - name: cp -a /usr/pkg/share/examples/rc.d/{{item}} /etc/rc.d/{{item}}
{% endfor %}

group dbus:
  group.present:
    - name: dbus
    - gid: 81
    - system: True

user dbus:
  user.present:
    - name: dbus
    - uid: 81
    - groups: [dbus]
    - fullname: System message bus
    - home: /
    - shell: /usr/bin/false

/etc/daily.orig:
  file.copy:
    - source: /etc/daily
    - force: False

change daily security mail output to log file:
  file.replace:
    - name: /etc/daily
    - pattern: '^(.*)(mail .*daily insecurity output.*)$'
    - repl: '\1#\2\n\1cat $SECOUT > /var/log/security.out'

Ensure run dbus-uuidgen in /etc/rc.local:
  file.replace:
    - name: /etc/rc.local
    - pattern: '.*dbus-uuidgen.*'
    #- repl: '/usr/pkg/bin/dbus-uuidgen --ensure=/var/lib/dbus/machine-id'
    - repl: '/usr/pkg/bin/dbus-uuidgen --ensure'
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
{#
{% for item in varsdict.distro_pkgs.services_enabled.split(' ') %}
'Enable service {{item}}':
  file.replace:
    - name: /etc/rc.conf
    - pattern: '^{{item}}=.*'
    - repl: '{{item}}=YES'
    - append_if_not_found: True
{% endfor %}

{% for item in varsdict.distro_pkgs.services_disabled.split(' ') %}
'Disable service {{item}}':
  file.replace:
    - name: /etc/rc.conf
    - pattern: '^{{item}}=.*'
    - repl: '{{item}}=NO'
    - append_if_not_found: True
{% endfor %}
#}
