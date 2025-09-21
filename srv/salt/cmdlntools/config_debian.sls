/etc/mail.rc:
  file.copy:
    - source: /root/init/common/smtp/linux/mail.rc.sample
    - force: False

{## #NOTE, nftables lacking sysvinit support
/etc/init.d/nftables:
  file.copy:
    - source: /usr/share/doc/nftables/examples/sysvinit/nftables.init
    # mode=['ugo+x' | 0755]
    - mode: 0755

{% for item in {'rexp': '^#!/bin/sh.*', 'line': '#!/bin/sh'}
   , {'rexp': '.*/sbin/nft.*', 'line': '/sbin/nft -f /etc/nftables.conf'} %}
'Change {{item.rexp}} to {{item.line}}':
  file.replace:
    - name: '/etc/network/if-pre-up.d/nftables'
    - pattern: '{{item.rexp}}'
    - repl: '{{item.line}}'
    - append_if_not_found: True
{% endfor %}#}

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

/etc/sudoers:
  file.line:
    - after: 'Defaults.*env_reset.*'
    - mode: ensure
    - match: 'Defaults.*secure_path=.*'
    - content: 'Defaults    secure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"'
