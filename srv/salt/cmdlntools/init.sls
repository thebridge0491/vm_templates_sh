{% from tpldir ~ "/map.jinja" import varsdict with context %}
{% set variant = {'artix': 'archlinux', 'arch': 'archlinux'}.get(
     grains['os_family']|lower, grains['os_family'])|lower %}

{% include 'cmdlntools/00install_pkgs.sls' %}
{% include 'cmdlntools/01config_sys.sls' %}
{% include 'cmdlntools/02toggle_svcs.sls' %}
