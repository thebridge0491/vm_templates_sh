{% from tpldir ~ "/map.jinja" import varsdict with context %}

'Fix text mode only grub config ; {{grains['os_family']|lower}} setup-xorg-base':
  cmd.run:
    - name: |
        setup-xorg-base
        sed -i 's|nomodeset | |' /etc/default/grub
        sed -i 's|text | |' /etc/default/grub
        grub-mkconfig -o /boot/grub/grub.cfg
