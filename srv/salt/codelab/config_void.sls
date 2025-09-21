Ensure run dbus-uuidgen in /etc/rc.local:
  file.replace:
    - name: /etc/rc.local
    - pattern: '.*dbus-uuidgen.*'
    #- repl: '/usr/bin/dbus-uuidgen --ensure=/etc/machine-id'
    - repl: '/usr/bin/dbus-uuidgen --ensure'
    - append_if_not_found: True
