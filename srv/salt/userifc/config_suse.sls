/etc/X11/xorg.conf.d:
  file.directory

{% for confX in ['10-evdev.conf', '40-libinput.conf'] %}
'Copy orig Xorg config files ({{confX}})':
  cmd.run:
    #- shell: /bin/sh
    - name: cp -an /usr/share/X11/xorg.conf.d/{{confX}} /etc/X11/xorg.conf.d/
{% endfor %}

{% for item in ['nomodeset ', 'text ', 'xdriver=vesa '] %}
'Fix text mode only default grub config "{{item}}"':
  file.replace:
    - name: /etc/default/grub
    - pattern: '{{item}}'
    - repl: ''
{% endfor %}

Run grub2-mkconfig:
  cmd.run:
    - name: |
        grub2-mkconfig -o /boot/grub2/grub.cfg
