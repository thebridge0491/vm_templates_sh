{% from tpldir ~ "/map.jinja" import varsdict with context %}

Fix text mode only grub config:
  cmd.run:
    - name: |
        sed -i 's|nomodeset | |' /etc/default/grub
        sed -i 's|text | |' /etc/default/grub
        grub-mkconfig -o /boot/grub/grub.cfg

{% if grains['os_family']|lower in ['artix'] %}
{% for item in ['displaymanager'] %}
'{{item}}-openrc package (variant: {{grains['os_family']|lower}})':
  cmd.run:
    - name: 'pacman -Sy --noconfirm --needed {{item}}-openrc'
{% endfor%}

{% if varsdict.desktop in ['lxqt'] %}
/etc/conf.d/xdm:
  file.replace:
    - pattern: '^DISPLAYMANAGER=.*'
    - repl: 'DISPLAYMANAGER="sddm"'
{% endif %}

{% if not varsdict.desktop in ['lxqt'] %}
/etc/conf.d/xdm:
  file.replace:
    - pattern: '^DISPLAYMANAGER=.*'
    - repl: 'DISPLAYMANAGER="lightdm"'
{% endif %}
{% endif %}
