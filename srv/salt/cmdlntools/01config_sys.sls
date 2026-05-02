{% from tpldir ~ "/map.jinja" import varsdict with context %}
{% set variant = {'artix': 'archlinux', 'arch': 'archlinux'}.get(
     grains['os_family']|lower, grains['os_family'])|lower %}

{% if grains['kernel']|lower in ['netbsd', 'openbsd'] %}
  {% if grains['kernel']|lower == 'netbsd' %}
Run dbus-uuidgen(netbsd):
  cmd.run:
    #- shell: /bin/sh
    - name: /usr/pkg/bin/dbus-uuidgen --ensure
  {% elif grains['kernel']|lower == 'openbsd' %}
Run dbus-uuidgen(openbsd):
  cmd.run:
    #- shell: /bin/sh
    - name: /usr/local/bin/dbus-uuidgen --ensure
  {% endif %}
{% endif %}

{% set idsuffix = salt['cmd.shell'](varsdict.idsuffix_cmd, shell='/bin/sh', ignore_retcode=True) %}
{#{% set hostname_0000_if = (grains.nodename|regex_match('(.*box.)0000'))[0] %}#}
{% set hostname_0000_if = grains.nodename|regex_match('(.*box.)0000') %}
{% if hostname_0000_if is not none %}
  {% for item in varsdict.hostname_chgfiles %}
{{item}}:
  file.replace:
    - pattern: '{{hostname_0000_if[0]}}0000'
    - repl: '{{hostname_0000_if[0]}}{{idsuffix}}'
  {% endfor %}

Fix hostname regexp box.0000:
  cmd.run:
    #- shell: /bin/sh
    - name: hostname '{{hostname_0000_if[0]}}{{idsuffix}}'
{% endif %}

Ensure /etc/profile.d directory:
  file.directory:
    - name: /etc/profile.d

{% set etcprofile_exists = salt['file.file_exists']('/etc/profile') %}
{% if not etcprofile_exists %}
Ensure /etc/profile file exists:
  cmd.run:
    - shell: /bin/sh
    - name: |
        if [ ! -e /etc/profile ] ; then
          cat << EOF > /etc/profile ;
        if [ -d /etc/profile.d ] ; then
          for i in /etc/profile.d/*.sh ; do
            if [ -r "${i}" ] ; then
              . "${i}" ;
            fi ;
          done ;
          unset i ;
        fi

        EOF
          chmod +x /etc/profile ;
        fi
{% endif %}

{% set out_java = salt['cmd.shell']('java -version', shell='/bin/sh', ignore_retcode=True) %}
{% if "not found" not in out_java %}
{#{% set found_java = salt['file.find']('/', name='java') %}
{% if [] != found_java %}#}
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

Chmod +x /etc/profile.d/jdk.sh:
  file.managed:
    - name: /etc/profile.d/jdk.sh
    - mode: 0755

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
  {% set found_mailcmds = salt['file.find']('/**/bin', iname='(nail|s-nail|mailx)') %}
  {% set mail_cmd = salt['file.basename'](found_mailcmds[0] | default("mail")) %}
'Send sample email using {{mail_cmd}}':
  cmd.run:
    #- shell: /bin/sh
    - name: echo Sample email | {{mail_cmd}} -r vagrant@{{grains["nodename"]}} \
        -s "Sample subject" root packer
{% endif %}
