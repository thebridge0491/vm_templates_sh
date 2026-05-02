{% set xorgconfd_dir_exists = salt['file.directory_exists']('/usr/share/X11/xorg.conf.d') %}
{% if xorgconfd_dir_exists %}
/etc/X11/xorg.conf.d:
  file.directory

  {% for confX in ['10-evdev.conf', '40-libinput.conf'] %}
'Copy orig Xorg config files ({{confX}})':
  cmd.run:
    #- shell: /bin/sh
    - name: cp -an /usr/share/X11/xorg.conf.d/{{confX}} /etc/X11/xorg.conf.d/
  {% endfor %}

  {#
  {% if grains.get('init', '')|lower != 'systemd' %}
Run update-alternatives x-session-manager (non-systemd):
  cmd.run:
    - name: |
        # Note, ex: dpkg-reconfigure lightdm
        # [/usr/[s]bin/[startxfce4 | startlxqt | lightdm | sddm | gdm3]
        #update-alternatives --set x-session-manager $(cat /etc/X11/default-display-manager)
        update-alternatives --config x-session-manager
  {% endif %}
  #}

/etc/X11/xorg.conf.d/10-modesetting.conf:
  file.blockreplace:
    - content: |
        #Section "Device"
        #  Identifier "Device0"
        #  Driver "modesetting"
        #  #BusID "PCI:0:2:0"
        #EndSection

    - append_if_not_found: True

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

{% for item in [' nomodeset', ' text', ' xdriver=vesa'] %}
'Fix text mode only default grub config "{{item}}"':
  file.replace:
    - name: /etc/default/grub
    - pattern: '{{item}}'
    - repl: ''
{% endfor %}

Run grub-mkconfig:
  cmd.run:
    - name: |
        grub-mkconfig -o /boot/grub/grub.cfg
