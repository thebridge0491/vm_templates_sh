{#{% set distrosets = ["xbase", "xserver", "xfont", "xetc"] %}
{% include 'common/fetch_distrosets.sls' %}#}

'set video resolution ? gop 6: 1024x768x32':
  file.replace:
    - name: /boot.cfg
    - pattern: ';boot'
    - repl: ';gop 6;boot'

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

{% for item in ['/var/run/dbus', '/var/db/dbus', '/var/run/xdm', '/var/lib/xdm'
   , '/usr/pkg/etc/xdm', '/usr/pkg/etc/xdg'] %}
'make dir {{item}}':
  file.directory:
    - name: {{item}}
{% endfor %}

{% for item in ['dbus', 'xdm'] %}
'Xfer /usr/pkg/share/examples/rc.d/{{item}} /etc/rc.d/{{item}}':
  cmd.run:
    #- shell: /bin/sh
    - name: cp -a /usr/pkg/share/examples/rc.d/{{item}} /etc/rc.d/{{item}}
{% endfor %}

Copy /usr/pkg/share/examples/xdm /usr/pkg/etc/xdm:
  file.copy:
    - name: /usr/pkg/etc/xdm
    - source: /usr/pkg/share/examples/xdm
    - mode: 0755

{% for item in ['xfce4', 'lxqt', 'kde'] %}
'Copy /usr/pkg/share/examples/{{item}} /usr/pkg/etc/xdg/':
  file.copy:
    - name: /usr/pkg/etc/xdg/{{item}}
    - source: /usr/pkg/share/examples/{{item}}
    - mode: 0755
{% endfor %}

/usr/pkg/etc/X11/xorg.conf.d:
  file.directory

{% set xorgconfd_dir_exists = salt['file.directory_exists']('/usr/pkg/share/X11/xorg.conf.d') %}
{% if xorgconfd_dir_exists %}
  {% for confX in ['10-evdev.conf', '40-libinput.conf'] %}
'Copy orig Xorg config files ({{confX}})':
  cmd.run:
    #- shell: /bin/sh
    - name: cp -an /usr/pkg/share/X11/xorg.conf.d/{{confX}} /usr/pkg/etc/X11/xorg.conf.d/
  {% endfor %}

  {#
Config Xorg touchpad tapping w/ shell script:
  cmd.run:
    #- shell: /bin/sh
    - name: sh /root/init/common/misc_config.sh cfg_xorgtouchpad /usr/pkg/etc/X11/xorg.conf.d
  #}

  {% for confX in ['10-evdev.conf', '40-libinput.conf'] %}
'Turn on Option Tapping /usr/pkg/etc/X11/xorg.conf.d/{{confX}}':
  file.line:
    - name: '/usr/pkg/etc/X11/xorg.conf.d/{{confX}}'
    - after: '^[^#]\s*MatchIsTouchpad.*'
    - mode: ensure
    - match: '.*Option "Tapping" "on".*'
    - content: '       Option "Tapping" "on"'
  {% endfor %}
{% endif %}

# /usr/pkg/etc/X11/xorg.conf.d/20-[wsfb|intel|radeon].conf
/usr/pkg/etc/X11/xorg.conf.d/20-wsfb.conf:
  file.blockreplace:
    - content: |
        Section "Device"
          Identifier "Card0"
          Driver "wsfb" # wsfb | intel | radeon
          #BusID "PCI:0:2:0"
        EndSection

    #- mode: 0755
    - append_if_not_found: True

/usr/pkg/etc/X11/xorg.conf.d/10-modesetting.conf:
  file.blockreplace:
    - content: |
        #Section "Device"
        #  Identifier "Card0"
        #  Driver "modesetting"
        #  #BusID "PCI:0:2:0"
        #EndSection

    - append_if_not_found: True

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

{% if varsdict.desktop in ['xfce'] %}
'Config /root/.xinitrc for {{varsdict.desktop}}':
  file.replace:
    - name: /root/.xinitrc
    - pattern: '^ck-launch-session.*'
    - repl: 'ck-launch-session dbus-launch --exit-with-session startxfce4'
    - append_if_not_found: True
{% elif varsdict.desktop in ['kde'] %}
'Config /root/.xinitrc for {{varsdict.desktop}}':
  file.replace:
    - name: /root/.xinitrc
    - pattern: '^ck-launch-session.*'
    - repl: 'ck-launch-session dbus-launch --exit-with-session startkde'
    - append_if_not_found: True
{% elif varsdict.desktop in ['lxqt'] %}
'Config /root/.xinitrc for {{varsdict.desktop}}':
  file.replace:
    - name: /root/.xinitrc
    - pattern: '^ck-launch-session.*'
    - repl: 'ck-launch-session dbus-launch --exit-with-session startlxqt'
    - append_if_not_found: True
{% endif %}

Copy /root/.xinitrc -> /home/packer/.xinitrc:
  file.copy:
    - source: /root/.xinitrc
    - dest: /home/packer/
    - user: packer

{% for item in ['/root', '/home/packer'] %}
'Symlink .xinitrc to .xsession ({{item}})':
  file.symlink:
    - name: {{item}}/.xsession
    - target: {{item}}/.xinitrc
{% endfor %}

{#
{% for item in varsdict.distro_pkgs.get("uiservices_enabled_" ~ varsdict.desktop, "").split(' ') %}
'Enable service {{item}}':
  file.replace:
    - name: /etc/rc.conf
    - pattern: '^{{item}}=.*'
    - repl: '{{item}}=YES'
    - append_if_not_found: True
{% endfor %}

{% for item in varsdict.distro_pkgs.get("uiservices_disabled_" ~ varsdict.desktop, "").split(' ') %}
'Disable service {{item}}':
  file.replace:
    - name: /etc/rc.conf
    - pattern: '^{{item}}=.*'
    - repl: '{{item}}=NO'
    - append_if_not_found: True
{% endfor %}
#}
