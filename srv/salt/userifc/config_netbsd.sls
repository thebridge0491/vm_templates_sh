{% set autoconfirm = salt['pillar.get']('state1', {}).get('autoconfirm', 'NO') %}
{% if (autoconfirm|to_bool) %}
  {% set uname_m = grains.cpuarch %}
  {% set rel = grains.osrelease %}
  {% for setX in ['xbase', 'xserver', 'xfont', 'xetc'] %}
{#'Fetch & extract missing distribution sets like: {{setX}}.tar.xz':
  archive.extracted:
    - name: /
    - source: 'http://cdn.netbsd.org/pub/NetBSD/NetBSD-{{rel}}/{{uname_m}}/binary/sets/{{setX}}.tar.xz'
    - skip_verify: True
    - options: pJ#}

'Fetch, then extract missing distribution sets like: {{setX}}.tar.xz':
  file.managed:
    - name: '/tmp/{{setX}}.tar.xz'
    - source: 'http://cdn.netbsd.org/pub/NetBSD/NetBSD-{{rel}}/{{uname_m}}/binary/sets/{{setX}}.tar.xz'
    - skip_verify: True
  archive.extracted:
    - name: /
    - source: '/tmp/{{setX}}.tar.xz'
    - options: pJ
	{% endfor %}
{% endif %}

{% for item in ['/var/run/dbus', '/var/db/dbus', '/var/run/xdm', '/var/lib/xdm'
   , '/usr/pkg/etc/xdm', '/usr/pkg/etc/xdg', '/usr/pkg/etc/X11/xorg.conf.d'] %}
'make dir {{item}}':
  file.directory:
    - name: {{item}}
{% endfor %}

{% for confX in ['10-evdev.conf', '40-libinput.conf'] %}
'Copy orig Xorg config files ({{confX}})':
  cmd.run:
    #- shell: /bin/sh
    - name: cp -an /usr/pkg/usr/pkg/share/X11/xorg.conf.d/{{confX}} /etc/X11/xorg.conf.d/
{% endfor %}

{% for item in ['dbus', 'xdm'] %}
Xfer /usr/pkg/share/examples/rc.d/{{item}} /etc/rc.d/{{item}}:
  cmd.run:
    #- shell: /bin/sh
    - name: cp -a /usr/pkg/share/examples/rc.d/{{item}} /etc/rc.d/{{item}}
{% endfor %}

Copy /usr/pkg/share/examples/xdm /usr/pkg/etc/xdm:
  file.copy:
    - name: /usr/pkg/etc/xdm
    - source: /usr/pkg/share/examples/xdm
    - mode: 0755

{% for item in ['xfce4', 'lxqt'] %}
'Copy /usr/pkg/share/examples/{{item}} /usr/pkg/etc/xdg/':
  file.copy:
    - name: /usr/pkg/etc/xdg/{{item}}
    - source: /usr/pkg/share/examples/{{item}}
    - mode: 0755
{% endfor %}

group dbus:
  group.present:
    - name: dbus
    - gid: 81
    - system: True

user dbus:
  user.present:
    - name: dbus
    - uid: 81
    - groups: [dbus]
    - fullname: System message bus
    - home: /
    - shell: /usr/bin/false

'set video resolution ? gop 6: 1024x768x32':
  file.replace:
    - name: /boot.cfg
    - pattern: ';boot'
    - repl: ';gop 6;boot'

touch /root/.xinitrc:
  file.touch:
    - name: /root/.xinitrc

{% for item in {'rexp': '^export XDG_DATA_DIRS=.*'
   , 'line': 'export XDG_DATA_DIRS=/usr/pkg/share'}
   , {'rexp': '^export XDG_CONFIG_DIRS=.*'
   , 'line': 'export XDG_CONFIG_DIRS=/usr/pkg/etc/xdg'} %}
'Change /root/.xinitrc {{item.rexp}} to {{item.line}}':
  file.replace:
    - name: /root/.xinitrc
    - pattern: '{{item.rexp}}'
    - repl: '{{item.line}}'
    - append_if_not_found: True
{% endfor %}

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

# /usr/pkg/etc/X11/xorg.conf.d/20-[wsfb|intel|radeon].conf
/usr/pkg/etc/X11/xorg.conf.d/20-wsfb.conf:
  file.blockreplace:
    - content:
        Section "Device"
          Identifier "Card0"
          Driver "wsfb" # wsfb | intel | radeon
          #BusID "PCI:0:2:0"
        EndSection
    #- mode: 0755
    - append_if_not_found: True

{#
{% for item in {{varsdict.distro_pkgs.get("uiservices_enabled_" ~ varsdict.desktop, "").split(' ')}} %}
'Enable service {{item}}':
  file.replace:
    - name: /etc/rc.conf
    - pattern: '^{{item}}=.*'
    - repl: '{{item}}=YES'
    - append_if_not_found: True
{% endfor %}

{% for item in {{varsdict.distro_pkgs.get("uiservices_disabled_" ~ varsdict.desktop, "").split(' ')}} %}
'Disable service {{item}}':
  file.replace:
    - name: /etc/rc.conf
    - pattern: '^{{item}}=.*'
    - repl: '{{item}}=NO'
    - append_if_not_found: True
{% endfor %}
#}
