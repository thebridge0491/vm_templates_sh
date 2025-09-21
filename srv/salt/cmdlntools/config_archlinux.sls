/etc/avahi/services/:
  file.copy:
    - source: /usr/share/doc/avahi/ssh.service

Change use-ipv6 to no in /etc/avahi/avahi-daemon.conf:
  file.replace:
    - name: /etc/avahi/avahi-daemon.conf
    - pattern: 'use-ipv6=yes'
    - repl: 'use-ipv6=no'

# for runit service ops w/ Ansible,Saltstack
{% if 'runit' == grains['init'] %}
  {% for item in {srcX: '/etc/runit/sv', destX: '/etc/sv'}
     , {srcX: '/run/runit/service', destX: '/var/service'} %}
     #, {srcX: '/etc/runit/runsvdir/default', destX: '/var/service'}
'Symlink {{item.srcX}} to {{item.destX}}':
  file.symlink:
    - name: {{item.destX}}
    - target: {{item.srcX}}
  {% endfor %}
{% endif %}

# Undo syslog-ng default logging disabled (comments: filter,destination)
/etc/syslog-ng/syslog-ng.conf.orig:
  file.copy:
    - source: /etc/syslog-ng/syslog-ng.conf
    - force: False

{% for item in ['filter', 'destination'] %}
'({{item}}) Undo syslog-ng default logging disabled in /etc/syslog-ng/syslog-ng.conf':
  file.replace:
    - name: /etc/syslog-ng/syslog-ng.conf
    - pattern: '^(.*)(#\s*)({{item}}.*)$'
    - repl: '\1\2\3\n\1\3'
{% endfor %}

{#
/var/lib/clamav:
  file.directory:
    - user: clamav
    - group: clamav
    - recurse:
      - user
      - group

/var/lib/clamav/clamd.sock:
  file.managed:
    - user: clamav
    - group: clamav
    - create: True
#}

#/etc/sudoers:
#  file.line:
#    - after: 'Defaults.*env_reset.*'
#    - mode: ensure
#    - match: 'Defaults.*secure_path=.*'
#    - content: 'Defaults    secure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"'
