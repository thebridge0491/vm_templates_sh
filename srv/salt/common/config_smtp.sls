{% if varsdict.smtp_daemon == 'sendmail' %}
'{{varsdict.smtp_daemon}}':
  service.running:
    - enable: True
    - reload: True

Backup old user mail directories:
  cmd.run:
    #- shell: /bin/sh
    - name: |
        for userX in root packer vagrant ; do
          [ ! -e /var/mail/${userX}.old ] && \
            mv /var/mail/${userX} /var/mail/${userX}.old ;
        done
{% endif %}

{% if varsdict.smtp_daemon in ['smtpd', 'opensmtpd'] %}
'{{varsdict.smtp_daemon}}':
  service.running:
    - enable: True
    - reload: True

  {% if grains.get('init', '')|lower in ['systemd'] %}
'Unmask {{varsdict.smtp_daemon}} ({{grains.get('init', '')}})':
  service.unmasked:
    - name: '{{varsdict.smtp_daemon}}'
  {% endif %}

  {#
  {% if grains['kernel']|lower in ['freebsd', 'netbsd', 'openbsd'] %}
'Config {{varsdict.smtp_daemon}} (bsd) w/ shell script':
  cmd.run:
    #- shell: /bin/sh
    - name: sh /root/init/common/smtp/bsd/config_opensmtpd.sh
  {% elif grains['kernel']|lower == 'linux' %}
'Config {{varsdict.smtp_daemon}} (linux) w/ shell script':
  cmd.run:
    #- shell: /bin/sh
    - name: sh /root/init/common/smtp/linux/config_opensmtpd.sh
  {% endif %}
  #}
  # smtpd.conf location varies:
  #  /etc/mail/smtpd.conf: OpenBSD, Alpine Linux
  #  /etc/smtpd/smtpd.conf: Void Linux, Arch Linux
  #  /etc/smtpd.conf: Debian
  {# {% set found_confs = salt['file.find']('/etc', name='smtpd.conf') %} #}
  {% set out_confs = salt['cmd.shell']('find /etc -name "smtpd.conf"', shell='/bin/sh').split() %}
  {% set path_conf = out_confs[0] | default("/etc/mail/smtpd.conf") %}
'{{path_conf}}.orig':
  file.copy:
    - source: '{{path_conf}}'

'Add commented table domains in {{path_conf}}':
  file.replace:
    - name: '{{path_conf}}'
    - pattern: '^(table aliases.*)$'
    - repl: '#table domains { {{grains["nodename"]}}, localhost }\n\1'
    - append_if_not_found: True

'Fix erroneous initial "local" maildir to "local" mbox in {{path_conf}}':
  file.replace:
    - name: '{{path_conf}}'
    - pattern: '^action "local" maildir(.*)$'
    - repl: 'action "local" mbox\1'
    - append_if_not_found: True

  {% if grains['kernel']|lower in ['openbsd'] %}
'Add "local_maildir" maildir in {{path_conf}} ({{grains["kernel"]|lower}})':
  file.blockreplace:
    - name: '{{path_conf}}'
    - content: |
        action "local_maildir" maildir "/var/mail/%{rcpt.user}" alias <aliases>
        match from local for local ! rcpt-to "root" action "local_maildir"

    - insert_before_match: '^action "local" mbox'
    - append_if_not_found: True
  {% else %}
'Add "local_maildir" maildir in {{path_conf}} ({{grains["kernel"]|lower}})':
  file.blockreplace:
    - name: '{{path_conf}}'
    - content: |
        action "local_maildir" maildir "/var/spool/mail/%{rcpt.user}" alias <aliases>
        match for local ! rcpt-to "root" action "local_maildir"

    - insert_before_match: '^action "local" mbox'
    - append_if_not_found: True
  {% endif %}

Backup old user mail directories:
  cmd.run:
    #- shell: /bin/sh
    - name: |
        for userX in packer vagrant ; do
          [ ! -e /var/mail/${userX}.old ] && \
            mv /var/mail/${userX} /var/mail/${userX}.old ;
        done

  {% if grains['kernel']|lower != 'linux' %}
/var/mail/packer:
  file.directory:
    - user: packer
    - group: wheel
  {% else %}
    {% for item in ['cur', 'new', 'tmp'] %}
'/var/mail/packer/{{item}}':
  file.directory:
    - user: packer
    - group: mail
    {% endfor %}
  {% endif %}
{% endif %}

{% if varsdict.smtp_daemon == 'postfix' %}
'{{varsdict.smtp_daemon}}':
  service.running:
    - enable: True
    - reload: True

  {% if grains.get('init', '')|lower in ['systemd'] %}
'Unmask {{varsdict.smtp_daemon}} ({{grains.get('init', '')}})':
  service.unmasked:
    - name: '{{varsdict.smtp_daemon}}'
  {% endif %}

  {% if grains['kernel']|lower != 'linux' %}
'Config {{varsdict.smtp_daemon}} (bsd)':
  cmd.run:
    #- shell: /bin/sh
    - name: |
        # [home_mailbox=Maildir/ | mail_spool_directory=/var/mail/]
        #echo "mail_spool_directory = /var/mail/" >> /etc/postfix/main.cf
        postconf mail_spool_directory=/var/mail/
        postfix reload
  {% else %}
'Config {{varsdict.smtp_daemon}} (linux)':
  cmd.run:
    #- shell: /bin/sh
    - name: |
        # [home_mailbox=Maildir/ | mail_spool_directory=/var/spool/mail/]
        #echo "mail_spool_directory = /var/spool/mail/" >> /etc/postfix/main.cf
        postconf mail_spool_directory=/var/spool/mail/
        postfix reload
  {% endif %}

Backup old user mail directories:
  cmd.run:
    #- shell: /bin/sh
    - name: |
        for userX in root packer vagrant ; do
          [ ! -e /var/mail/${userX}.old ] && \
            mv /var/mail/${userX} /var/mail/${userX}.old ;
        done

  {#{% if grains['kernel']|lower != 'linux' %}
/var/mail/packer:
  file.directory:
    - user: packer
    - group: wheel
  {% endif %}#}

  {% if grains['kernel']|lower == 'linux' %}
/var/spool/mail/postfix:
  file.directory:
    - user: postfix
    - group: postfix
  {% endif %}

  {% if variant in ['mageia', 'pclinuxos'] %}
Symlink /var/spool/mail/postfix to /var/spool/mail/root:
  file.symlink:
    - name: /var/spool/mail/root
    - target: /var/spool/mail/postfix
  {% endif %}
{% endif %}
