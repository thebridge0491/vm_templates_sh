{% from tpldir ~ "/map.jinja" import varsdict with context %}

Config apt-get no install recommends:
  cmd.run:
    #- shell: /bin/sh
    - name: |
        apt-config dump | grep -we Recommends -e Suggests | sed 's|1|0|' | \
          tee /etc/apt/apt.conf.d/999norecommends

Fix text mode only grub config:
  cmd.run:
    - name: |
        sed -i 's|nomodeset | |' /etc/default/grub
        sed -i 's|text | |' /etc/default/grub
        grub-mkconfig -o /boot/grub/grub.cfg
