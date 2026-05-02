{% from tpldir ~ "/map.jinja" import varsdict with context %}
{% set variant = {'artix': 'archlinux', 'arch': 'archlinux'}.get(
     grains['os_family']|lower, grains['os_family'])|lower %}

{% include 'userifc/00install_pkgs.sls' %}
{% include 'userifc/01config_sys.sls' %}
{% include 'userifc/02toggle_svcs.sls' %}
