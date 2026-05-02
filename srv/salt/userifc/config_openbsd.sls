{#{% set distrosets = ["xbase", "xserv", "xfont", "xshare"] %}
{% include 'common/fetch_distrosets.sls' %}#}

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

touch /etc/sysctl.conf:
  file.touch:
    - name: /etc/sysctl.conf

Change /etc/sysctl.conf ^machdep.allowaperture=.* to machdep.allowaperture=2:
  file.replace:
    - name: /etc/sysctl.conf
    - pattern: '^machdep.allowaperture=.*'
    - repl: 'machdep.allowaperture=2'
    - append_if_not_found: True

Change /etc/rc.local ^export XDG_CONFIG_HOME=.* to export XDG_CONFIG_HOME=/etc/xdg:
  file.replace:
    - name: /etc/rc.local
    - pattern: '^export XDG_CONFIG_HOME=.*'
    - repl: 'export XDG_CONFIG_HOME=/etc/xdg'
    - append_if_not_found: True

/etc/X11/xorg.conf.d:
  file.directory

{% set xorgconfd_dir_exists = salt['file.directory_exists']('/usr/local/share/X11/xorg.conf.d') %}
{% if xorgconfd_dir_exists %}
  {#
  {% for confX in ['10-evdev.conf', '40-libinput.conf'] %}
'Copy orig Xorg config files ({{confX}})':
  cmd.run:
    #- shell: /bin/sh
    - name: cp -an /usr/local/share/X11/xorg.conf.d/{{confX}} /etc/X11/xorg.conf.d/
  {% endfor %}
  #}

  {#
Config Xorg touchpad tapping w/ shell script:
  cmd.run:
    #- shell: /bin/sh
    - name: sh /root/init/common/misc_config.sh cfg_xorgtouchpad /etc/X11/xorg.conf.d
  #}

  {% for confX in ['10-evdev.conf', '40-libinput.conf'] %}
'Turn on Option Tapping /etc/X11/xorg.conf.d/{{confX}}':
  file.line:
    - name: '/etc/X11/xorg.conf.d/{{confX}}'
    - after: '^[^#]\s*MatchIsTouchpad.*'
    - mode: ensure
    - match: '.*Option "Tapping" "on".*'
    - content: '       Option "Tapping" "on"'
  {% endfor %}
{% endif %}

# /etc/X11/xorg.conf.d/20-[wsfb|intel|radeon].conf
/etc/X11/xorg.conf.d/20-wsfb.conf:
  file.blockreplace:
    - content: |
        Section "Device"
          Identifier "Card0"
          Driver "wsfb" # wsfb | intel | radeon
          #BusID "PCI:0:2:0"
        EndSection

    #- mode: 0755
    - append_if_not_found: True

/etc/X11/xorg.conf.d/10-modesetting.conf:
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
    {#- repl: 'ck-launch-session dbus-launch --exit-with-session startkde'#}
    - repl: 'ck-launch-session dbus-launch --exit-with-session startplasma-x11'
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
