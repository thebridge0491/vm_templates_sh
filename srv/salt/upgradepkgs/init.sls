{% from tpldir ~ "/map.jinja" import varsdict with context %}
{% set variant = grains['os_family']|lower %}

#include:
#  - upgradepkgs.nano

'Upgrade packages (variant: {{variant}})':
  {% if variant == 'freebsd' %}
  cmd.run:
    - name: |
        env PAGER=cat freebsd-update fetch
        env PAGER=cat freebsd-update install || true
        pkg update ; pkg fetch -udy ; pkg upgrade -y ; pkg clean -y
  {% elif variant in ['artix'] %}
  cmd.run:
    - name: pacman -Sy ; pacman -Syu
  {% elif variant == 'alpine' %}
  cmd.run:
    - name: apk update ; apk fix ; apk upgrade -U -a
  {% elif variant == 'pclinuxos' %}
  cmd.run:
    - name: |
        apt-get -y update ; apt-get -y --fix-broken install
        apt-get -y upgrade ; apt-get -y dist-upgrade
  {% elif variant in ['centos stream', 'mageia'] %}
  cmd.run:
    - name: dnf -y check-update ; dnf -y upgrade ; dnf -y clean all
  {% elif variant == 'openbsd' %}
  cmd.run:
    - name: pkg_add -u
  {% else %}
  pkg.uptodate
  {% endif %}
