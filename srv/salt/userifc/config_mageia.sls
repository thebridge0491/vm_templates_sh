{% from tpldir ~ "/map.jinja" import varsdict with context %}

Config dnf install_weak_deps:
  cmd.run:
    #- shell: /bin/sh
    - name: |
        dnf --setopt=install_weak_deps=False config-manager --save
        dnf config-manager --dump | grep -we install_weak_deps

Fix text mode only grub config ; systemd set default graphical.target:
  cmd.run:
    - name: |
        systemctl set-default graphical.target

        sed -i 's|nomodeset | |' /etc/default/grub
        sed -i 's|text | |' /etc/default/grub
        grub2-mkconfig -o /boot/grub2/grub.cfg
