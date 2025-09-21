{% set autoconfirm = salt['pillar.get']('state1', {}).get('autoconfirm', 'NO') %}
{% if (autoconfirm|to_bool) %}
  {% set uname_m = grains.cpuarch %}
  {% set release = grains.osrelease ~ '-RELEASE' %}
  {% for setX in ['src'] %}
{#'Fetch & extract missing distribution components like: {{setX}}.txz':
  archive.extracted:
    - name: /
    - source: 'ftp://ftp.freebsd.org/pub/FreeBSD/releases/{{uname_m}}/{{release}}/{{setX}}.txz'
    - skip_verify: True
    - options: zv#}

'Fetch, then extract missing distribution components ({{setX}}.txz)':
  file.managed:
    - name: '/tmp/{{setX}}.txz'
    - source: 'ftp://ftp.freebsd.org/pub/FreeBSD/releases/{{uname_m}}/{{release}}/{{setX}}.txz'
    - skip_verify: True
  {#archive.extracted:
    - name: /
    - source: '/tmp/{{setX}}.txz'
    - options: zv#}
	{% endfor %}
{% endif %}

{% for item in ['/boot/loader.conf', '/etc/rc.conf'] %}
'touch {{item}}':
  file.touch:
    - name: {{item}}
{% endfor %}

{% for item in {'flagX': 'devfs_system_ruleset', 'valX': 'devfsrules_system'}
   , {'flagX': 'syslogd_flags', 'valX': '-ss'}
   , {'flagX': 'ntpd_sync_on_start', 'valX': "'YES'"}
   , {'flagX': 'cron_flags', 'valX': '-J 60 -j 60'} %}
   #, {'flagX': 'anacron_flags', 'valX': '+= -s'}    # note: += for append value
   #, {'flagX': 'mountd_flags', 'valX': '-r'}
'sysrc config {{item.flagX}}':
  sysrc.managed:
    - name: {{item.flagX}}
    - value: {{item.valX}}
{% endfor %}

#sysrc config anticongestion_sleeptime:
#  sysrc.managed:
#    - name: anticongestion_sleeptime
#    - value: 3600
#    - file: /etc/periodic.conf

{% for item in {'flagX': 'daily_clean_tmps_enable', 'valX': "'NO'"}
   , {'flagX': 'daily_status_ntpd_enable', 'valX': "'YES'"}
   , {'flagX': 'daily_status_disks_df_flags', 'valX': '-lhT -c'}
   , {'flagX': 'daily_output', 'valX': "''"}
   , {'flagX': 'weekly_output', 'valX': "''"}
   , {'flagX': 'monthly_output', 'valX': "''"}
   , {'flagX': 'daily_status_security_output', 'valX': '/var/log/security.out'} %}
   #, {'flagX': 'daily_clean_tmps_days', 'valX': '15'}
'sysrc config {{item.flagX}} in /etc/periodic.conf':
  sysrc.managed:
    - name: {{item.flagX}}
    - value: {{item.valX}}
    - file: /etc/periodic.conf
{% endfor %}

touch /etc/devfs.rules:
  file.touch:
    - name: /etc/devfs.rules

config /etc/devfs.rules:
  file.blockreplace:
    - name: /etc/devfs.rules
    - content: |
        [devfsrules_system=10]
        add path 'unlpt*' group cups mode 0660
        add path 'ulpt*' group cups mode 0660
        add path 'lpt*' group cups mode 0660

        #NOTE, find USB device correspond to printer: dmesg | grep -e ugen
        #add path 'usb/X.Y.Z' group cups mode 0660
    - append_if_not_found: True

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
  {% elif grains['kernel']|lower in ['freebsd', 'openbsd'] %}
'Symlink lp* cmds (printing) [/usr/local/bin/{{item}} to /usr/bin/{{item}}]':
  file.symlink:
    - name: /usr/bin/{{item}}
    - target: /usr/local/bin/{{item}}
  {% endif %}
{% endfor %}
