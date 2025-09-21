
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

{% for item in ['/etc/freshclam.conf', '/etc/clamd.d/scan.conf'] %}
'Comment example {{item}}':
  file.replace:
    - name: {{item}}
    - pattern: '^Example'
    - repl: '#Example'
{% endfor %}

/etc/clamd.d/scan.conf:
  file.replace:
    - pattern: '^#\s*LocalSocket'
    - repl: 'LocalSocket'
#}

#/etc/sudoers:
#  file.line:
#    - after: 'Defaults.*env_reset.*'
#    - mode: ensure
#    - match: 'Defaults.*secure_path=.*'
#    - content: 'Defaults    secure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"'
