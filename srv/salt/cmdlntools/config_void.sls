'Packages socklog & socklog-void removed (variant: {{grains["os_family"]|lower}})':
  pkg.removed:
    - pkgs: ['socklog', 'socklog-void']

/var/log/socklog:
  file.absent

Ensure run dbus-uuidgen in /etc/rc.local:
  file.replace:
    - name: /etc/rc.local
    - pattern: '.*dbus-uuidgen.*'
    #- repl: '/usr/bin/dbus-uuidgen --ensure=/etc/machine-id'
    - repl: '/usr/bin/dbus-uuidgen --ensure'
    - append_if_not_found: True

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
#  file.replace:
#    - pattern: 'Defaults.*secure_path=.*'
#    - repl: 'Defaults    secure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"'
