{% from tpldir ~ "/map.jinja" import varsdict with context %}
{% set variant = {'artix': 'archlinux', 'arch': 'archlinux',
     'centos stream': 'redhat'}.get(grains['os_family']|lower,
     grains['os_family'])|lower %}
{% set pkgs_var = varsdict.distro_pkgs.pkgs_displaysvr_xorg|replace("\"", "")+" "+varsdict.distro_pkgs.get("pkgs_deskenv_"+varsdict.desktop, "")|replace("\"", "") %}

'User interface packages (variant: {{variant}})':
  {#cmd.run:
    #- shell: /bin/sh
    - name: echo {{varsdict.distro_pkgs.pkgs_displaysvr_xorg}}#}
  test.show_notification:
    - text: '{{pkgs_var}}'
  {% if grains['os_family']|lower in ['artix'] %}
  cmd.run:
    - name: pacman -Sy --noconfirm --needed {{pkgs_var}}
  {% elif grains['os_family']|lower in ['pclinuxos'] %}
  cmd.run:
    - name: apt-get -y --fix-broken install {{pkgs_var}}
  {% elif grains['os_family']|lower in ['centos stream', 'mageia'] %}
  cmd.run:
    - name: dnf -y install {{pkgs_var}}
  {% elif grains['os_family']|lower in ['openbsd'] %}
  cmd.run:
    - name: pkg_add -zIU {{pkgs_var}}
  {% else %}
  pkg.installed:
    - pkgs: {{pkgs_var.split(' ')}}
  {% endif %}

# conditionally(exists if count > 0) include file
{% if salt['cp.list_master'](prefix=tpldir ~ '/config_' ~ variant ~ '.sls')|count %}
include:
  - {{tpldot}}.config_{{variant}}
{% endif %}

{{varsdict.xdguserdirs_file}}:
  file.replace:
    - pattern: '^BIN=.*'
    - repl: 'BIN=bin'

Update XDG user dir config:
  cmd.run:
    - shell: /bin/sh
    - name: |
        export LANG=en_US.UTF-8 ; export CHARSET=UTF-8
        xdg-user-dirs-update ; chmod 1777 /tmp

'Enable user interface related service(s) (desktop: {{varsdict.desktop}})':
  service.enabled:
    - names: {{varsdict.uiservices_enabled}}
