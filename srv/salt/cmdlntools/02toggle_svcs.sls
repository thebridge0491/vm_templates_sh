{% from tpldir ~ "/map.jinja" import varsdict with context %}
{% set variant = {'artix': 'archlinux', 'arch': 'archlinux'}.get(
     grains['os_family']|lower, grains['os_family'])|lower %}

{% if grains.get('init', '')|lower in ['openrc'] %}
  {% set name_task = 'toggle cmdline-tools service(s)' %}
  {% set svcs_enabled = varsdict.distro_pkgs.services_enabled|replace('rsyslog ', '') %}
  {% set svcs_disabled = varsdict.distro_pkgs.services_disabled|replace('syslog ', '') %}

'Enable {{name_task}} rsyslog runlevel boot ({{grains.get("init", "")}})':
  service.enabled:
    - names: [rsyslog]
    - runlevels: [boot]

'Disable {{name_task}} syslog runlevel boot ({{grains.get("init", "")}})':
  service.disabled:
    - names: [syslog]
    - runlevels: [boot]

  {% include 'common/togglesvcs.sls' %}
{% else %}
  {% set name_task = 'toggle cmdline-tools service(s)' %}
  {% set svcs_enabled = varsdict.distro_pkgs.services_enabled %}
  {% set svcs_disabled = varsdict.distro_pkgs.services_disabled %}
  {% include 'common/togglesvcs.sls' %}
{% endif %}

Clean pkg cache:
  {% if not salt['sys.list_functions']('pkg.clean') %}
  cmd.run:
    #- shell: /bin/sh
    - name: {{varsdict.pkgclean_cmd}}
  {% else %}
  module.run:
    - pkg.clean:
      #- clean_all: True
  {% endif %}
