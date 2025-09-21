{% from tpldir ~ "/map.jinja" import varsdict with context %}
{% set variant = {'artix': 'archlinux', 'arch': 'archlinux'}.get(
     grains['os_family']|lower, grains['os_family'])|lower %}

{% set dateutc = salt['system.get_system_date']('+0000')|strftime('%Y%m%d') %}
{% set snapshot_name = salt['pillar.get']('state1', {}).get('snapshot_name', 'pre_cmdlntools-'+dateutc) %}
{% include 'upgradepkgs/snapshot.sls' %}

{% if variant in ['archlinux'] %}
Service pamac stopped & path /var/lib/pacman/db.lck absent:
  service.disabled:
    - names: [pamac]
  file.absent:
    - name: /var/lib/pacman/db.lck
{% endif %}

{% if variant in ['debian', 'pclinuxos'] %}
Config apt no install recommends:
  cmd.run:
    #- shell: /bin/sh
    - name: |
        apt-config dump | grep -we Recommends -e Suggests | sed 's|1|0|' | \
          tee /etc/apt/apt.conf.d/999norecommends

/etc/apt/apt.conf.d/99force-ipv4:
  file.replace:
    - pattern: 'Acquire::ForceIPv4.*'
    - repl: '#Acquire::ForceIPv4 "true";'
    - append_if_not_found: True

/etc/apt/apt.conf.d/99retries03:
  file.replace:
    - pattern: '^Acquire::Retries.*;'
    - repl: 'Acquire::Retries "3";'
    - append_if_not_found: True
{% endif %}

{% if variant in ['suse'] %}
Config zypper solver only requires:
  file.replace:
    - name: /etc/zypp/zypp.conf
    - pattern: '.*solver.onlyRequires.*=.*'
    - repl: 'solver.onlyRequires = true'
    - append_if_not_found: True

Config zypper no install recommends:
  file.replace:
    - name: /etc/zypp/zypp.conf
    - pattern: '.*installRecommends.*=.*'
    - repl: 'installRecommends = no'
    - append_if_not_found: True

Ensure packages netcat-openbsd removed:
  pkg.removed:
    - pkgs: ['netcat-openbsd']
{% endif %}

{% if variant in ['redhat', 'mageia'] %}
Config dnf no install weak depns:
  cmd.run:
    #- shell: /bin/sh
    - name: |
        dnf --setopt=install_weak_deps=False config-manager --save
        dnf config-manager --dump | grep -we install_weak_deps
{% endif %}

Refresh pkg db:
  {% if not salt['sys.list_functions']('pkg.refresh_db') %}
    {% if variant == 'pclinuxos' %}
  cmd.run:
    #- shell: /bin/sh
    - name: apt-get -y update
    {% endif %}
  {% else %}
  module.run:
    - pkg.refresh_db:
  {% endif %}

Display cmdline-tools packages:
  {#cmd.run:
    #- shell: /bin/sh
    - name: echo {{varsdict.distro_pkgs.pkgs_cmdln_tools}}#}
  test.show_notification:
    - text: '{{varsdict.distro_pkgs.pkgs_cmdln_tools}}'

{% set autoconfirm = salt['pillar.get']('state1', {}).get('autoconfirm', 'YES') %}
{% if not (autoconfirm|to_bool) %}
Check autoconfirm is "yes":
  test.fail_without_changes:
    - name: "Stopping execution pillar={'state1': {'autoconfirm': '{{autoconfirm}}'}}"
    - failhard: True
{% endif %}

{% if grains['os_family']|lower in ['pclinuxos'] %}
Install cmdline-tools packages:
  cmd.run:
    #- shell: /bin/sh
    - name: |
        for pkgX in {{varsdict.distro_pkgs.pkgs_cmdln_tools}} ; do
          apt-get --fix-broken -y install ${pkgX} ;
        done
{% elif grains['os_family']|lower in ['suse', 'redhat', 'mageia', 'netbsd', 'openbsd'] %}
Install cmdline-tools packages:
  pkg.installed:
    - pkgs: {{varsdict.distro_pkgs.pkgs_cmdln_tools.split(' ')}}
    - kwargs:
      # suse zypper .. --ignore-unknown ; redhat dnf .. --skip-broken
      ignore_unknown: True
      #get_extra_options: True
      skip_broken: True
{% else %}
Install cmdline-tools packages:
  pkg.installed:
    - pkgs: {{varsdict.distro_pkgs.pkgs_cmdln_tools.split(' ')}}

  {% for pkgX in varsdict.distro_pkgs.pkgs_cmdln_tools.split(' ') %}
'retry failed Install cmdline-tools packages ({{pkgX}})':
  pkg.installed:
    - name: {{pkgX}}
    - onfail:
      - pkg: 'Install cmdline-tools packages'
  {% endfor %}
{% endif %}

{% set idsuffix = salt['cmd.shell'](varsdict.idsuffix_cmd, shell='/bin/sh') %}
{% set hostname_0000_if = (grains.nodename|regex_match('(.*box.)0000'))[0] %}
{% if hostname_0000_if %}
  {% for item in varsdict.hostname_chgfiles %}
{{item}}:
  file.replace:
    - pattern: '{{hostname_0000_if}}0000'
    - repl: '{{hostname_0000_if}}{{idsuffix}}'
  {% endfor %}

Fix hostname regexp box.0000:
  cmd.run:
    #- shell: /bin/sh
    - name: hostname '{{hostname_0000_if}}{{idsuffix}}'
{% endif %}

{#{% set out_java = salt['cmd.shell']('java -version || echo ""', shell='/bin/sh') %}
{% if '' != out_java %}#}
{% set found_java = salt['file.find']('/', name='java') %}
{% if [] != found_java %}
  {#{% set out_javahome = salt['cmd.shell']('dirname $(dirname $(realpath $(which java)))', shell='/bin/sh') %}#}
  {% set out_javahome = salt['cmd.shell']('realpath $(which java) | sed "s:/bin/java::"', shell='/bin/sh') %}
  {#
  {% if 'csh' in salt['environ.get']('SHELL') %}
/etc/csh.cshrc:
  file.replace:
    - pattern: '^setenv JAVA_HOME.*'
    - repl: 'setenv JAVA_HOME {{out_javahome}}'
    - append_if_not_found: True
  {% endif %}
  {% if 'bash' in salt['environ.get']('SHELL') %}
/etc/bash.bashrc:
  file.replace:
    - pattern: '^export JAVA_HOME.*'
    - repl: 'export JAVA_HOME={{out_javahome}}'
    - append_if_not_found: True
  {% endif %}
  {% if 'ksh' in salt['environ.get']('SHELL') %}
/etc/ksh.kshrc:
  file.replace:
    - pattern: '^export JAVA_HOME.*'
    - repl: 'export JAVA_HOME={{out_javahome}}'
    - append_if_not_found: True
  {% endif %}
  #}
/etc/profile.d/jdk.sh:
  file.replace:
    - pattern: '^export JAVA_HOME.*'
    - repl: 'export JAVA_HOME={{out_javahome}}'
    - append_if_not_found: True
  {% if grains['kernel']|lower not in ['linux'] %}
/etc/fstab:
  file.replace:
    - pattern: '^fdesc.*'
    - repl: 'fdesc  /dev/fd  fdescfs  rw  0  0'
    - append_if_not_found: True
  {% endif %}
{% endif %}

Set group and permissions on /var/mail:
{#{% if variant in ['netbsd', 'openbsd'] %}
  file.directory:
    - name: /var/mail
    - follow_symlinks: True
    - group: wheel
    # mode: 'g+ws,+t' | 3775
    - mode: 3775#}
{% if variant in ['mageia', 'pclinuxos'] %}
  file.directory:
    - name: /var/mail
    - follow_symlinks: True
    - group: postfix
    # mode: 'g+ws,+t' | 3775
    - mode: 3775
{% else %}
  file.directory:
    - name: /var/mail
    - follow_symlinks: True
    - group: mail
    # mode: 'g+ws,+t' | 3775
    - mode: 3775
{% endif %}

Setup skeleton paths:
  file.directory:
    - names: {{varsdict.skel_dirs}}

{% for item in varsdict.skelmaps_srcdest %}
'Xfer {{item.srcskel}} to {{item.destskel}}':
  cmd.run:
    #- shell: /bin/sh
    - name: cp -a /root/init/common/skel/{{item.srcskel}} {{varsdict.skeldir_par}}/{{item.destskel}}
{% endfor %}


# conditionally(exists if count > 0) include file
{% if salt['cp.list_master'](prefix=tpldir ~ '/config_' ~ variant ~ '.sls')|count %}
{#include:
  - {{tpldot}}.config_{{variant}}#}
{% include tpldir ~ '/config_' ~ variant ~ '.sls' %}
{% endif %}

{% include 'common/config_cron.sls' %}

{% include 'common/config_smtp.sls' %}

{% include 'common/config_firewall.sls' %}

#include:
#  - common.misc_config
{% include 'common/misc_config.sls' %}

Display printer (cups) status:
  cmd.run:
    #- shell: /bin/sh
    - name: lpstat -t || true

{% if grains.get('init', '')|lower in ['openrc'] %}
'Enable service(s) ({{grains.get("init", "")}})':
  service.enabled:
    - names: {{(varsdict.distro_pkgs.services_enabled|replace('rsyslog ', '')).split(' ')}}

'Enable service rsyslog runlevel boot ({{grains.get("init", "")}})':
  service.enabled:
    - names: [rsyslog]
    - runlevels: [boot]
{% else %}
'Enable service(s) ({{grains.get("init", "")}})':
  service.enabled:
    - names: {{varsdict.distro_pkgs.services_enabled.split(' ')}}
{% endif %}

{% if grains.get('init', '')|lower in ['systemd'] %}
'Unmask service(s) ({{grains.get("init", "")}})':
  service.unmasked:
    - names: {{varsdict.distro_pkgs.services_enabled.split(' ')}}
{% endif %}

{% if grains.get('init', '')|lower in ['openrc'] %}
'Disable service(s) ({{grains.get("init", "")}})':
  service.disabled:
    - names: {{(varsdict.distro_pkgs.services_disabled|replace('syslog ', '')).split(' ')}}

'Disable service syslog runlevel boot ({{grains.get("init", "")}})':
  service.disabled:
    - names: [syslog]
    - runlevels: [boot]
{% else %}
'Disable service(s) ({{grains.get("init", "")}})':
  service.disabled:
    - names: {{varsdict.distro_pkgs.services_disabled.split(' ')}}
{% endif %}

{% if grains.get('init', '')|lower in ['systemd'] %}
'Mask service(s) ({{grains.get("init", "")}})':
  service.masked:
    - names: {{varsdict.distro_pkgs.services_disabled.split(' ')}}
{% endif %}

Send email sample using sendmail:
  cmd.run:
    #- shell: /bin/sh
    - name: |
        cat << EOF | sendmail -t root
        To: packer
        Subject: Subject sample

        Email sample
        EOF

{% if grains['kernel']|lower in ['freebsd'] %}
Send sample email using mail:
  cmd.run:
    #- shell: /bin/sh
    - name: echo Sample email | mail -u vagrant -s "Sample subject" root packer
{% else %}
  {% set found_mailcmds = salt['file.find']('/', name='nail|s-nail|mailx') %}
  {% set mail_cmd = salt['file.basename'](found_mailcmds[0] | default("mail")) %}
'Send sample email using {{mail_cmd}}':
  cmd.run:
    #- shell: /bin/sh
    - name: echo Sample email | {{mail_cmd}} -r vagrant@{{grains["nodename"]}} \
        -s "Sample subject" root packer
{% endif %}

Clean pkg cache:
  {% if not salt['sys.list_functions']('pkg.clean') %}
  cmd.run:
    #- shell: /bin/sh
    - name: {{varsdict.pkgclean_cmd}}
  {% else %}
  module.run:
    - pkg.clean:
      #- clean_all: True
  {% endif %}
