{% from tpldir ~ "/map.jinja" import varsdict with context %}

Fix text mode only grub config:
  cmd.run:
    - name: |
        sed -i 's|nomodeset | |' /etc/default/grub
        sed -i 's|text | |' /etc/default/grub
        grub-mkconfig -o /boot/grub/grub.cfg
