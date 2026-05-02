{% from tpldir ~ "/map.jinja" import varsdict with context %}
{% set variant = {'artix': 'archlinux', 'arch': 'archlinux'}.get(
     grains['os_family']|lower, grains['os_family'])|lower %}

{% set name_task = 'toggle coding lab related service(s)' %}
{% set svcs_enabled = varsdict.distro_pkgs.labservices_enabled %}
{% set svcs_disabled = varsdict.distro_pkgs.labservices_disabled %}
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
