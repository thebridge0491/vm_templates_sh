{% set autoconfirm = salt['pillar.get']('state1', {}).get('autoconfirm', 'NO') %}
{% if (autoconfirm|to_bool) %}
  {% set uname_m = grains.cpuarch %}
  {% set rel = grains.osrelease %}
  {% for setX in ['xbase'] %}
{#'Fetch & extract missing distribution sets like: {{setX}}.tar.xz':
  archive.extracted:
    - name: /
    - source: 'http://cdn.netbsd.org/pub/NetBSD/NetBSD-{{rel}}/{{uname_m}}/binary/sets/{{setX}}.tar.xz'
    - skip_verify: True
    - options: pJ#}

'Fetch, then extract missing distribution sets like: {{setX}}.tar.xz':
  file.managed:
    - name: '/tmp/{{setX}}.tar.xz'
    - source: 'http://cdn.netbsd.org/pub/NetBSD/NetBSD-{{rel}}/{{uname_m}}/binary/sets/{{setX}}.tar.xz'
    - skip_verify: True
  {#archive.extracted:
    - name: /
    - source: '/tmp/{{setX}}.tar.xz'
    - options: pJ#}
	{% endfor %}
{% endif %}

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
