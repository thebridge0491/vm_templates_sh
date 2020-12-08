{#{% from tpldir ~ "/map.jinja" import varsdict with context %}#}
{% set variant = grains['os_family']|lower %}

include:
  - upgradepkgs.nano
