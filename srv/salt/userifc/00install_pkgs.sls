{% from tpldir ~ "/map.jinja" import varsdict with context %}
{% set variant = {'artix': 'archlinux', 'arch': 'archlinux'}.get(
     grains['os_family']|lower, grains['os_family'])|lower %}

{% set dateutc = salt['system.get_system_date']('+0000')|strftime('%Y%m%d') %}
{% set snapshot_name = salt['pillar.get']('state1', {}).get('snapshot_name', 'pre_userifc-'+dateutc) %}
{% if grains['kernel']|lower not in ['netbsd', 'openbsd'] %}
{% include 'upgradepkgs/snapshot.sls' %}
{% endif %}

{% if variant in ['archlinux'] %}
'Service pamac stopped & path /var/lib/pacman/db.lck absent':
  service.disabled:
    - names: [pamac]
  file.absent:
    - name: /var/lib/pacman/db.lck
{% endif %}

{% if variant in ['debian', 'pclinuxos'] %}
Config apt no install recommends:
  cmd.run:
    #- shell: /bin/sh
    - name: |
        apt-config dump | grep -we Recommends -e Suggests | sed 's|1|0|' | \
          tee /etc/apt/apt.conf.d/999norecommends

/etc/apt/apt.conf.d/99force-ipv4:
  file.replace:
    - pattern: 'Acquire::ForceIPv4.*'
    - repl: '#Acquire::ForceIPv4 "true";'
    - append_if_not_found: True

/etc/apt/apt.conf.d/99retries03:
  file.replace:
    - pattern: '^Acquire::Retries.*;'
    - repl: 'Acquire::Retries "3";'
    - append_if_not_found: True
{% endif %}

{% if variant in ['suse'] %}
Config zypper solver only requires:
  file.replace:
    - name: /etc/zypp/zypp.conf
    - pattern: '.*solver.onlyRequires.*=.*'
    - repl: 'solver.onlyRequires = true'
    - append_if_not_found: True

Config zypper no install recommends:
  file.replace:
    - name: /etc/zypp/zypp.conf
    - pattern: '.*installRecommends.*=.*'
    - repl: 'installRecommends = no'
    - append_if_not_found: True

Ensure packages netcat-openbsd removed:
  pkg.removed:
    - pkgs: ['netcat-openbsd']
{% endif %}

{% if variant in ['redhat', 'mageia'] %}
'Config dnf no install weak depns':
  cmd.run:
    #- shell: /bin/sh
    - name: |
        dnf --setopt=install_weak_deps=False config-manager --save
        dnf config-manager --dump | grep -we install_weak_deps
{% endif %}

{% if grains['kernel']|lower != 'openbsd' %}
Refresh pkg db:
  {#{% if not salt['sys.list_functions']('pkg.refresh_db') %}#}
  {% if 'pkg.refresh_db' not in salt['sys.list_functions']() %}
    {% if variant == 'pclinuxos' %}
  cmd.run:
    #- shell: /bin/sh
    - name: apt-get -y update
    {% else %}
  module.run:
    - test.echo:
      - text: 'Not needed'
    {% endif %}
  {% else %}
  module.run:
    - pkg.refresh_db:
  {% endif %}
{% endif %}

'Display user interface packages ({{varsdict.desktop}})':
  {#cmd.run:
    #- shell: /bin/sh
    - name: echo {{varsdict.distro_pkgs.get("pkgs_deskenv_" ~ varsdict.desktop, "")|replace("\"", "")}}#}
  test.show_notification:
    - text: '{{(varsdict.distro_pkgs.get("pkgs_deskenv_" ~ varsdict.desktop, "")|replace("\"", "")).split(" ")|yaml}}'

{% set autoconfirm = salt['pillar.get']('state1', {}).get('autoconfirm', 'YES') %}
{% if not (autoconfirm|to_bool) %}
Check autoconfirm is "yes":
  test.fail_without_changes:
    - name: "Stopping execution pillar={'state1': {'autoconfirm': '{{autoconfirm}}'}}"
    - failhard: True
{% endif %}

{% if variant == 'alpine' %}
# setup-[wayland | xorg]-base
'Setup xorg (alpine)':
  cmd.run:
    #- shell: /bin/sh
    - name: setup-xorg-base
{% endif %}

{% set name_task = 'Install user interface packages (' ~ varsdict.desktop ~ ')' %}
{% set pkgs_var = varsdict.distro_pkgs.get('pkgs_deskenv_' ~ varsdict.desktop, '')|replace('\"', '') %}
{% include 'common/installpkgs.sls' %}
