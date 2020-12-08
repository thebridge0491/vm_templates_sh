nano:
  {% if grains['os_family']|lower in ['artix'] %}
  cmd.run:
    - name: pacman -Sy --noconfirm --needed nano
  {% elif grains['os_family']|lower in ['pclinuxos'] %}
  cmd.run:
    - name: apt-get -y --fix-broken install nano
  {% elif grains['os_family']|lower in ['centos stream', 'mageia'] %}
  cmd.run:
    - name: dnf -y install nano
  {% else %}
  pkg.installed
  {% endif %}
