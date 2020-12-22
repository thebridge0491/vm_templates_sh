{% from tpldir ~ "/map.jinja" import varsdict with context %}
{% set variant = {'artix': 'archlinux', 'arch': 'archlinux'}.get(
     grains['os_family']|lower, grains['os_family'])|lower %}
{% set pkgs_var = varsdict.distro_pkgs.pkgs_displaysvr_xorg|replace("\"", "")+" "+varsdict.distro_pkgs.get("pkgs_deskenv_"+varsdict.desktop, "")|replace("\"", "") %}

'(duplicate install) User interface packages (variant: {{variant}})':
  cmd.run:
    #- shell: /bin/sh
    - name: apt-get -y --fix-broken install {{pkgs_var}}

Fix text mode only grub config ; drakconf user interface:
  cmd.run:
    - name: |
        apt-get -y --fix-broken install
        XFdrake --auto
        #drakx11 ; sleep 5 ; drakdm ; sleep 5 ; drakboot ; sleep 5
        mv /etc/X11/xorg.conf /etc/X11/xorg.conf.bak || true
        #chkconfig --add dm ; chkconfig dm on

        sed -i 's|nomodeset | |' /etc/default/grub
        sed -i 's|text | |' /etc/default/grub
        sed -i 's|noacpi | |' /etc/default/grub
        sed -i 's|xdriver=vesa | |' /etc/default/grub
        touch /etc/system-release
        grub2-mkconfig -o /boot/grub2/grub.cfg
