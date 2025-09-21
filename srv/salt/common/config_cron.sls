{#
{% if grains['kernel']|lower in ['freebsd', 'linux'] %}
#clean old /tmp directories:
#  cron.present:
#    - name: find /tmp/* -maxdepth 0 -type d -atime +15 -print0 | xargs -0 rm -irf
#    - user: root
#    - special: '@daily'
#
#clean old /tmp files:
#  cron.present:
#    - name: find /tmp/* -maxdepth 0 -type f -atime +15 -print0 | xargs -0 rm -if
#    - user: root
#    - special: '@daily'

  {% if grains['kernel']|lower == 'freebsd' %}
    {% set dailycleantmp_file = '/etc/periodic/daily/999.cleantmp' %}
  {% elif grains['kernel']|lower == 'linux' %}
    {% if variant == 'alpine' %}
      {% set dailycleantmp_file = '/etc/periodic/daily/900cleantmp' %}
    {% else %}
      {% set dailycleantmp_file = '/etc/cron.daily/900cleantmp' %}
    {% endif %}
  {% endif %}

'Config {{dailycleantmp_file}}':
  file.managed:
    - name: '{{dailycleantmp_file}}'
    - content: |
        #!/bin/sh

        find /tmp/* -maxdepth 0 -type d -atime +15 -print0 | xargs -0 rm -irf
        find /tmp/* -maxdepth 0 -type f -atime +15 -print0 | xargs -0 rm -if
    # mode=['ugo+x' | 0755]
    - mode: 0755
    - append_if_not_found: True

{% endif %}
#}

{% if grains['kernel']|lower in ['freebsd', 'netbsd', 'openbsd'] %}
#Config cron (bsd) w/ shell script:
#  cmd.run:
#    #- shell: /bin/sh
#    - name: sh /root/init/common/cron/bsd/config_cron.sh

  {% for item in ['daily', 'weekly', 'monthly'] %}
    {% if grains['kernel']|lower == 'freebsd' %}
'Config /etc/periodic/{{item}}/0anacron':
  file.managed:
    - name: '/etc/periodic/{{item}}/0anacron'
    - content: |
        #!/bin/sh

        #anacron -u {job} --> date +%Y%m%d > /var/spool/anacron/{job}
        /usr/local/sbin/anacron -u {{item}}
    # mode=['ugo+x' | 0755]
    - mode: 0755
    - append_if_not_found: True
    {% elif grains['kernel']|lower in ['netbsd', 'openbsd'] %}
'Ensure shebang in /etc/{{item}}.local':
  file.managed:
    - name: '/etc/{{item}}/local'
    - content: |
        #!/bin/sh

    # mode=['ugo+x' | 0755]
    - mode: 0755
    - append_if_not_found: True

'Config /etc/{{item}}.local':
  file.managed:
    - name: '/etc/{{item}}/local'
    - content: |
        #anacron -u {job} --> date +%Y%m%d > /var/spool/anacron/{job}
        /usr/local/sbin/anacron -u {{item}}
    # mode=['ugo+x' | 0755]
    - mode: 0755
    - append_if_not_found: True
      {% if grains['kernel']|lower in ['netbsd'] %}
Change /usr/local/sbin -> /usr/pkg/sbin (netbsd):
  file.replace:
    - name: '/etc/{{item}}/local'
    - pattern: '/usr/local/sbin'
    - repl: '/usr/pkg/sbin'
      {% endif %}
    {% endif %}
  {% endfor %}

  {% for item in ['/var/cron/tabs/root', '/etc/crontab'
     , '/usr/local/etc/anacrontab', '/usr/pkg/etc/anacrontab'] %}
'{{item}}.orig':
  file.copy:
    - source: {{item}}
    - force: False
  {% endfor %}

  {% for item in ['/var/cron/tabs/root', '/etc/crontab'
     , '/usr/local/etc/anacrontab', '/usr/pkg/etc/anacrontab'] %}
    {% if grains['kernel']|lower == 'freebsd' %}
'Comment periodic daily|weekly|monthly {{item}}':
  file.replace:
    - name: {{item}}
    - pattern: '^([^#].*periodic [daiwekmonth]*ly.*)$'
    - repl: '#\1'
    {% elif grains['kernel']|lower in ['netbsd', 'openbsd'] %}
'Comment /bin/sh /etc/daily|weekly|monthly {{item}}':
  file.replace:
    - name: {{item}}
    - pattern: '^([^#].*/etc/[daiwekmonth]*ly.*)$'
    - repl: '#\1'
    {% endif %}
  {% endfor %}

  {% set tail_anacrontab = salt['file.read']('/root/init/common/cron/bsd/anacrontab_tail.sample') %}
  {% if grains['kernel']|lower == 'netbsd' %}
/usr/pkg/etc/anacrontab:
  file.copy:
    - source: /root/init/common/cron/bsd/anacrontab_head.sample
    - force: False

Config /usr/pkg/etc/anacrontab:
  file.blockreplace:
    - name: /usr/pkg/etc/anacrontab
    - content: {{tail_anacrontab.split('\n')}}
    - append_if_not_found: True
  {% elif grains['kernel']|lower in ['freebsd', 'openbsd'] %}
/usr/local/etc/anacrontab:
  file.copy:
    - source: /root/init/common/cron/bsd/anacrontab_head.sample
    - force: False

Config /usr/local/etc/anacrontab:
  file.blockreplace:
    - name: /usr/local/etc/anacrontab
    - content: {{tail_anacrontab.split('\n')}}
    - append_if_not_found: True
  {% endif %}

/etc/crontab:
  file.copy:
    - source: /root/init/common/cron/bsd/crontab_syshead.sample
    - force: False

/etc/cron.d:
  file.directory

touch /etc/crontab:
  file.touch:
    - name: /etc/crontab

{#
  {% set tail_crontabroot = salt['file.read']('/root/init/common/cron/bsd/crontab_roottail.sample') %}
Config /var/cron/tabs/root:
  file.blockreplace:
    - name: /var/cron/tabs/root
    - content: {{tail_crontabroot.split('\n')}}
    - append_if_not_found: True
#}

  {% set tail_crondperiodic = salt['file.read']('/root/init/common/cron/bsd/crond_periodic.sample') %}
Config /etc/cron.d/periodic:
  file.blockreplace:
    # name: /etc/cron.d/periodic | /etc/crontab
    - name: /etc/cron.d/periodic
    - content: {{tail_crondperiodic.split('\n')}}
    - append_if_not_found: True

Config /etc/cron.d/anacron:
  file.blockreplace:
    - name: /etc/cron.d/anacron
    - content: |
        02  6-22   *   *   *   root    /usr/local/sbin/anacron -s
    - append_if_not_found: True

  {% if grains['kernel']|lower in ['netbsd', 'openbsd'] %}
    {% for item in ['/var/cron/tabs/root', '/etc/crontab'
       , '/usr/local/etc/anacrontab', '/usr/pkg/etc/anacrontab'
       , '/etc/cron.d/periodic'] %}
'Change periodic daily|weekly|monthly -> /bin/sh /etc/daily|weekly|monthly{{item}}':
  file.replace:
    - name: {{item}}
    - pattern: 'periodic ([daiwekmonth]*ly)'
    - repl: '/bin/sh /etc/\1'
      {% if grains['kernel']|lower == 'netbsd' %}
'Change /usr/local/sbin -> /usr/pkg/sbin (netbsd) {{item}}':
  file.replace:
    - name: {{item}}
    - pattern: '/usr/local/sbin'
    - repl: '/usr/pkg/sbin'
      {% elif grains['kernel']|lower == 'openbsd' %}
'Remove tail command unknown option -v (openbsd) {{item}}':
  file.replace:
    - name: {{item}}
    - pattern: 'tail -vn+1'
    - repl: 'tail -n+1 .'
      {% endif %}
    {% endfor %}
  {% endif %}
{% endif %}

{% if grains['kernel']|lower == 'linux' %}
#Config cron (linux) w/ shell script:
#  cmd.run:
#    #- shell: /bin/sh
#    - name: sh /root/init/common/cron/linux/config_cron.sh

  {% for item in ['daily', 'weekly', 'monthly'] %}
    {% if variant == 'alpine' %}
'Config /etc/periodic/{{item}}/0anacron':
  file.managed:
    - name: '/etc/periodic/{{item}}/0anacron'
    - content: |
        #!/bin/sh

        #anacron -u {job} --> date +%Y%m%d > /var/spool/anacron/{job}
        anacron -u cron.{{item}}
    # mode=['ugo+x' | 0755]
    - mode: 0755
    - append_if_not_found: True
    {% else %}
'Config /etc/cron.{{item}}/0anacron':
  file.managed:
    - name: '/etc/cron.{{item}}/0anacron'
    - content: |
        #!/bin/sh

        #anacron -u {job} --> date +%Y%m%d > /var/spool/anacron/{job}
        anacron -u cron.{{item}}
    # mode=['ugo+x' | 0755]
    - mode: 0755
    - append_if_not_found: True
    {% endif %}
  {% endfor %}

  {% if variant == 'alpine' %}
/etc/periodic/daily/999dailystats:
  file.copy:
    - source: /root/init/common/cron/linux/cron_daily_999dailystats.sample
    # mode=['ugo+x' | 0755]
    - mode: 0755
  {% else %}
/etc/cron.daily/999dailystats:
  file.copy:
    - source: /root/init/common/cron/linux/cron_daily_999dailystats.sample
    # mode=['ugo+x' | 0755]
    - mode: 0755
  {% endif %}

  {% for item in ['/var/spool/cron/root', '/var/spool/cron/crontabs/root'
     , '/etc/crontab', '/etc/anacrontab'] %}
'{{item}}.orig':
  file.copy:
    - source: {{item}}
    - force: False
{% endfor %}

  {% for item in ['/var/spool/cron/root', '/var/spool/cron/crontabs/root'
     , '/etc/crontab', '/etc/anacrontab'] %}
    {% if variant == 'alpine' %}
'Comment /etc/periodic/daily|weekly|monthly {{item}}':
  file.replace:
    - name: {{item}}
    - pattern: '^([^#].*/etc/periodic/[daiwekmonth]*ly.*)$'
    - repl: '#\1'
    {% else %}
'Comment cron.daily|weekly|monthly {{item}}':
  file.replace:
    - name: {{item}}
    - pattern: '^([^#].*cron\.[daiwekmonth]*ly.*)$'
    - repl: '#\1'
      {% if variant == 'suse' %}
comment run-crons (suse) {{item}}:
  file.replace:
    - name: {{item}}
    - pattern: '^([^#].*run-crons.*)$'
    - repl: '#\1'
      {% endif %}
    {% endif %}
  {% endfor %}

/etc/anacrontab:
  file.copy:
    - source: /root/init/common/cron/linux/anacrontab_head.sample
    - force: False

{% set tail_anacrontab = salt['file.read']('/root/init/common/cron/linux/anacrontab_tail.sample') %}
Config /etc/anacrontab:
  file.blockreplace:
    - name: /etc/anacrontab
    - content: {{tail_anacrontab.split('\n')}}
    - append_if_not_found: True

/etc/crontab:
  file.copy:
    - source: /root/init/common/cron/linux/crontab_syshead.sample
    - force: False

/etc/cron.d:
  file.directory

touch /etc/crontab:
  file.touch:
    - name: /etc/crontab

  {% if variant == 'alpine' %}
    {% set tail_crontabroot = salt['file.read']('/root/init/common/cron/linux/crontab_roottail.sample') %}
Config /var/cron/tabs/root:
  file.blockreplace:
    - name: /var/spool/cron/crontabs/root
    - content: {{tail_crontabroot.split('\n')}}
    - append_if_not_found: True

Config /etc/periodic/hourly/0anacron:
  file.managed:
    - name: '/etc/periodic/hourly/0anacron'
    - content: |
        #!/bin/sh

        anacron -s
    # mode=['ugo+x' | 0755]
    - mode: 0755
    - append_if_not_found: True
  {% else %}
    {% set tail_crondperiodic = salt['file.read']('/root/init/common/cron/linux/crond_periodic.sample') %}
Config /etc/cron.d/periodic:
  file.blockreplace:
    # name: /etc/cron.d/periodic | /etc/crontab
    - name: /etc/cron.d/periodic
    - content: {{tail_crondperiodic.split('\n')}}
    - append_if_not_found: True

{#Config /etc/cron.hourly/0anacron:
  file.managed:
    - name: '/etc/cron.hourly/0anacron'
    - content: |
        #!/bin/sh

        anacron -s
    # mode=['ugo+x' | 0755]
    - mode: 0755
    - append_if_not_found: True#}

Config /etc/cron.d/anacron:
  file.blockreplace:
    - name: /etc/cron.d/anacron
    - content: |
        02  6-22   *   *   *   root    anacron -s
    - append_if_not_found: True
  {% endif %}

  {% set out_runpartscmd = salt['cmd.shell']('run-parts --help | grep -e "--report" || true', shell='/bin/sh') %}
  {% for item in ['/var/spool/cron/root', '/var/spool/cron/crontabs/root'
     , '/etc/crontab', '/etc/anacrontab', '/etc/cron.d/periodic'] %}
    {% if variant == 'alpine' %}
'Change /etc/cron.{job} -> /etc/periodic/{job} (alpine) {{item}}':
  file.replace:
    - name: {{item}}
    - pattern: '/etc/cron.([daiwekmonth]*ly)'
    - repl: '/etc/periodic/\1'
    {% endif %}

    {% if '' != out_runpartscmd %}
'Use run-parts option --report {{item}}':
  file.replace:
    - name: {{item}}
    - pattern: 'run-parts /etc'
    - repl: 'run-parts --report /etc'
    {% endif %}
  {% endfor %}
{% endif %}
