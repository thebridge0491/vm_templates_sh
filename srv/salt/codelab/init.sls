{% from tpldir ~ "/map.jinja" import varsdict with context %}
{% set variant = {'artix': 'archlinux', 'arch': 'archlinux'}.get(
     grains['os_family']|lower, grains['os_family'])|lower %}

{% include 'codelab/00install_pkgs.sls' %}
{% include 'codelab/01config_sys.sls' %}
{% include 'codelab/02toggle_svcs.sls' %}
