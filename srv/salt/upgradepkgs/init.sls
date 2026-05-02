{% from tpldir ~ "/map.jinja" import varsdict with context %}
{% set variant = {'artix': 'archlinux', 'arch': 'archlinux'}.get(
     grains['os_family']|lower, grains['os_family'])|lower %}

{% set dateutc = salt['system.get_system_date']('+0000')|strftime('%Y%m%d') %}
{% set snapshot_name = salt['pillar.get']('state1', {}).get('snapshot_name', variant+'_'+grains['osrelease']+'-'+dateutc) %}
{% if grains['kernel']|lower not in ['netbsd', 'openbsd'] %}
{% include 'upgradepkgs/snapshot.sls' %}
{% endif %}

{% if variant in ['archlinux'] %}
Service pamac stopped & path /var/lib/pacman/db.lck absent:
  service.disabled:
    - names: [pamac]
  file.absent:
    - name: /var/lib/pacman/db.lck
{% endif %}

{% if variant in ['debian', 'pclinuxos'] %}
/etc/apt/apt.conf.d/99retries03:
  file.replace:
    - pattern: '^Acquire::Retries.*;'
    - repl: 'Acquire::Retries "3";'
    - append_if_not_found: True
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

List repos:
  {#{% if not salt['sys.list_functions']('pkg.list_repos') %}#}
  {% if 'pkg.list_repos' not in salt['sys.list_functions']() %}
  cmd.run:
    #- shell: /bin/sh
    - name: {{varsdict.pkgrepos_cmd}}
  {% else %}
  module.run:
    - pkg.list_repos:
  {% endif %}

List outdated packages:
  {#{% if not salt['sys.list_functions']('pkg.list_upgrades') %}#}
  {% if 'pkg.list_upgrades' not in salt['sys.list_functions']() %}
  cmd.run:
    #- shell: /bin/sh
    - name: {{varsdict.pkgoutdated_cmd}}
  {% else %}
  module.run:
    - pkg.list_upgrades:
  {% endif %}

{#{% set response = salt['cmd.run']('read -p "Enter \'yes\' to continue [yesNO]: " response ; echo ${response}') %}#}
{% set autoconfirm = salt['pillar.get']('state1', {}).get('autoconfirm', 'NO') %}
{% if not (autoconfirm|to_bool) %}
Check autoconfirm is "yes":
  test.fail_without_changes:
    - name: "Stopping execution pillar={'state1': {'autoconfirm': '{{autoconfirm}}'}}"
    - failhard: True
{% endif %}

Upgrade packages:
  {% if variant in ['openbsd', 'pclinuxos'] %}
    {% if variant == 'openbsd' %}
  cmd.run:
    #- shell: /bin/sh
    - name: pkg_add -u
    {% elif variant == 'pclinuxos' %}
  cmd.run:
    #- shell: /bin/sh
    - name: apt-get -y dist-upgrade
    {% endif %}
  {% else %}
  #module.run:
  #  - pkg.upgrade:
  pkg.uptodate
  {% endif %}

{% set name_task = 'install nano' %}
{#{% set pkgs_var = 'pkgUnknown nano pkgMissing zip' %}#}
#include:
#  - common.installpkgs
{% include 'common/installpkgs.sls' %}

{% if grains['kernel']|lower not in ['netbsd', 'openbsd'] %}
List pkg locks:
  {% set funcs_lock = salt['sys.list_functions']('pkg.list_locked', 'pkg.list_locks'
      , 'pkg.list_holds', 'pkg.get_selections') %}
  {% if not funcs_lock %}
  cmd.run:
    #- shell: /bin/sh
    - name: {{varsdict.pkglocks_cmd}}
  {% else %}
    {% if 'pkg.get_selections' == funcs_lock[0] %}
  module.run:
    - {{funcs_lock[0]}}:
      - state: hold
    {% else %}
  module.run:
    {#- name: {{funcs_lock[0]}}#}
    - {{funcs_lock[0]}}:
    {% endif %}
  {% endif %}
{% endif %}


{#{% if grains['kernel']|lower in ['freebsd'] %}#}
{% if salt['sys.list_functions']('freebsd_update.fetch') %}
Run freebsd-update [fetch|install]:
  cmd.run:
    #- shell: /bin/sh
    - name: |
        # Unset these as if they're empty it'll break freebsd-update
        [ -z "${no_proxy}" ] && unset no_proxy
        [ -z "${http_proxy}" ] && unset http_proxy
        [ -z "${https_proxy}" ] && unset https_proxy

        grep -ie CreateBootEnv /etc/freebsd-update.conf
        bectl list ; bectl list -c creation

        env PAGER=cat freebsd-update --not-running-from-cron fetch
        env PAGER=cat freebsd-update --not-running-from-cron install || true
  {#module.run:
    - freebsd_update.fetch:
    - freebsd_update.install:#}
{% endif %}

{% if variant in ['debian', 'suse'] %}
Dist-upgrade packages:
  {#module.run:
    - pkg.upgrade:
      - dist_upgrade: True#}
  pkg.uptodate:
    - dist_upgrade: True
{% endif %}

{% if grains['kernel']|lower in ['linux'] %}
  {% set found_result = salt['file.find']('/usr', name='qemu-bridge-helper') %}
  {% if [] != found_result %}
Re-set setuid for qemu-bridge-helper:
  file.managed:
    - name: {{found_result[0]}}
    # mode: 'u+s' | 4755
    - mode: 4755
  {% endif %}
{% endif %}

Clean pkg cache:
  {#{% if not salt['sys.list_functions']('pkg.clean') %}#}
  {% if 'pkg.clean' not in salt['sys.list_functions']() %}
  cmd.run:
    #- shell: /bin/sh
    - name: {{varsdict.pkgclean_cmd}}
  {% else %}
  module.run:
    - pkg.clean:
      - clean_all: True
  {% endif %}
