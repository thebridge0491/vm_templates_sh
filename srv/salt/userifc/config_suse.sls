{% from tpldir ~ "/map.jinja" import varsdict with context %}

Config zypp solver.onlyRequires & zypper installRecommends:
  cmd.run:
    #- shell: /bin/sh
    - name: |
        sed -i 's|.*solver.onlyRequires.*=.*|solver.onlyRequires = true|' \
          /etc/zypp/zypp.conf
        sed -i 's|.*installRecommends.*=.*|installRecommends = no|' \
          /etc/zypp/zypper.conf

Install desktop patterns:
  pkg.installed:
    - pkgs: ['+pattern:x11', '+pattern:{{varsdict.desktop}}']

Fix text mode only grub config:
  cmd.run:
    - name: |
        sed -i 's|nomodeset | |' /etc/default/grub
        sed -i 's|text | |' /etc/default/grub
        grub2-mkconfig -o /boot/grub2/grub.cfg
