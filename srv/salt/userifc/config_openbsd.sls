{% set autoconfirm = salt['pillar.get']('state1', {}).get('autoconfirm', 'NO') %}
{% if (autoconfirm|to_bool) %}
  {% set arch_s = grains.cpuarch %}
  {% set rel = grains.osrelease %}
  {% set setVer = grains.osrelease|replace('.', '') %}
  {% for setX in ['xbase', 'xserv', 'xfont', 'xshare'] %}
{#'Fetch & extract missing distribution sets like: {{setX}}*.tgz':
  archive.extracted:
    - name: /
    - source: 'http://cdn.openbsd.org/pub/OpenBSD/{{rel}}/{{arch_s}}/{{setX}}{{setVer}}.tgz'
    - skip_verify: True
    - options: pz#}

'Fetch, then extract missing distribution sets like: {{setX}}*.tgz':
  file.managed:
    - name: '/tmp/{{setX}}{{setVer}}.tgz'
    - source: 'http://cdn.openbsd.org/pub/OpenBSD/{{rel}}/{{arch_s}}/{{setX}}{{setVer}}.tgz'
    - skip_verify: True
  archive.extracted:
    - name: /
    - source: '/tmp/{{setX}}{{setVer}}.tgz'
    - options: pz
	{% endfor %}

sysmerge updates:
  cmd.run:
    #- shell: /bin/sh
    - name: sysmerge
{% endif %}

touch /etc/rc.local:
  file.touch:
    - name: /etc/rc.local

Ensure run dbus-uuidgen in /etc/rc.local:
  file.replace:
    - name: /etc/rc.local
    - pattern: '.*dbus-uuidgen.*'
    #- repl: '/usr/local/bin/dbus-uuidgen --ensure=/etc/machine-id'
    - repl: '/usr/local/bin/dbus-uuidgen --ensure'
    - append_if_not_found: True

/etc/X11/xorg.conf.d:
  file.directory

{#
{% for confX in ['10-evdev.conf', '40-libinput.conf'] %}
'Copy orig Xorg config files ({{confX}})':
  cmd.run:
    #- shell: /bin/sh
    - name: cp -an /usr/local/share/X11/xorg.conf.d/{{confX}} /etc/X11/xorg.conf.d/
{% endfor %}
#}

Change /etc/rc.local ^export XDG_CONFIG_HOME=.* to export XDG_CONFIG_HOME=/etc/xdg:
  file.replace:
    - name: /etc/rc.local
    - pattern: '^export XDG_CONFIG_HOME=.*'
    - repl: 'export XDG_CONFIG_HOME=/etc/xdg'
    - append_if_not_found: True

touch /etc/sysctl.conf:
  file.touch:
    - name: /etc/sysctl.conf

Change /etc/sysctl.conf ^machdep.allowaperture=.* to machdep.allowaperture=2:
  file.replace:
    - name: /etc/sysctl.conf
    - pattern: '^machdep.allowaperture=.*'
    - repl: 'machdep.allowaperture=2'
    - append_if_not_found: True

touch /root/.xinitrc:
  file.touch:
    - name: /root/.xinitrc

{% if varsdict.desktop in ['lxqt'] %}
'Config /root/.xinitrc for {{varsdict.desktop}}':
  file.replace:
    - name: /root/.xinitrc
    - pattern: '^ck-launch-session.*'
    - repl: 'ck-launch-session dbus-launch --exit-with-session startlxqt'
    - append_if_not_found: True
{% elif varsdict.desktop in ['xfce'] %}
'Config /root/.xinitrc for {{varsdict.desktop}}':
  file.replace:
    - name: /root/.xinitrc
    - pattern: '^ck-launch-session.*'
    - repl: 'ck-launch-session dbus-launch --exit-with-session startxfce4'
    - append_if_not_found: True
{% endif %}

/home/packer/.xinitrc:
  file.copy:
    - source: /root/.xinitrc
    - user: packer

{% for item in ['/root', '/home/packer'] %}
'Symlink .xinitrc to .xsession ({{item}})':
  file.symlink:
    - name: {{item}}/.xsession
    - target: {{item}}/.xinitrc
{% endfor %}
