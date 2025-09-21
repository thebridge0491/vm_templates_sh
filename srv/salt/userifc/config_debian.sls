/etc/X11/xorg.conf.d:
  file.directory

{% for confX in ['10-evdev.conf', '40-libinput.conf'] %}
'Copy orig Xorg config files ({{confX}})':
  cmd.run:
    #- shell: /bin/sh
    - name: cp -an /usr/share/X11/xorg.conf.d/{{confX}} /etc/X11/xorg.conf.d/
{% endfor %}

{% if grains.get('init', '')|lower != 'systemd' %}
Run update-alternatives x-session-manager (non-systemd):
  cmd.run:
    - name: |
        # Note, ex: dpkg-reconfigure lightdm
        # [/usr/[s]bin/[startxfce4 | startlxqt | lightdm | sddm | gdm3]
        update-alternatives --set x-session-manager $(cat /etc/X11/default-display-manager)
{% endif %}

{% for item in ['nomodeset ', 'text ', 'xdriver=vesa '] %}
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
