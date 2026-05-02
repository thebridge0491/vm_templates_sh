{% from tpldir ~ "/map.jinja" import varsdict with context %}
{% set variant = {'artix': 'archlinux', 'arch': 'archlinux'}.get(
     grains['os_family']|lower, grains['os_family'])|lower %}

{% if grains.get('init', '')|lower in ['systemd'] %}
Set graphical.target default for systemd:
  cmd.run:
    #- shell: /bin/sh
    - name: systemctl set-default graphical.target
{% endif %}

{% set name_task = 'toggle user interface related service(s)' %}
{% set svcs_enabled = varsdict.distro_pkgs.get("uiservices_enabled_" ~ varsdict.desktop, "") %}
{% set svcs_disabled = varsdict.distro_pkgs.get("uiservices_disabled_" ~ varsdict.desktop, "") %}
{% include 'common/togglesvcs.sls' %}

'Clean pkg cache':
  {% if not salt['sys.list_functions']('pkg.clean') %}
  cmd.run:
    #- shell: /bin/sh
    - name: {{varsdict.pkgclean_cmd}}
  {% else %}
  module.run:
    - pkg.clean:
      - clean_all: True
  {% endif %}
