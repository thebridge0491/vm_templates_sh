{% from tpldir ~ "/map.jinja" import varsdict with context %}
{% set variant = {'artix': 'archlinux', 'arch': 'archlinux'}.get(
     grains['os_family']|lower, grains['os_family'])|lower %}
{% set pkgs_var = varsdict.distro_pkgs.pkgs_displaysvr|replace("\"", "")+" "+varsdict.distro_pkgs.get("pkgs_deskenv_" ~ varsdict.desktop, "")|replace("\"", "") %}

{% set dateutc = salt['system.get_system_date']('+0000')|strftime('%Y%m%d') %}
{% set snapshot_name = salt['pillar.get']('state1', {}).get('snapshot_name', 'pre_userifc-'+dateutc) %}
{% include 'upgradepkgs/snapshot.sls' %}

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

'Refresh pkg db':
  {% if not salt['sys.list_functions']('pkg.refresh_db') %}
    {% if variant == 'pclinuxos' %}
  cmd.run:
    #- shell: /bin/sh
    - name: apt-get -y update
    {% endif %}
  {% else %}
  module.run:
    - pkg.refresh_db:
  {% endif %}

'Display user interface packages ({{varsdict.desktop}})':
  {#cmd.run:
    #- shell: /bin/sh
    - name: echo {{pkgs_var}}#}
  test.show_notification:
    - text: '{{pkgs_var}}'

{% set autoconfirm = salt['pillar.get']('state1', {}).get('autoconfirm', 'YES') %}
{% if not (autoconfirm|to_bool) %}
Check autoconfirm is "yes":
  test.fail_without_changes:
    - name: "Stopping execution pillar={'state1': {'autoconfirm': '{{autoconfirm}}'}}"
    - failhard: True
{% endif %}

{% if grains['os_family']|lower == 'alpine' %}
'Setup xorg (alpine)':
  cmd.run:
    #- shell: /bin/sh
    - name: setup-xorg-base
{% endif %}

{% if grains['os_family']|lower in ['pclinuxos'] %}
'Install user interface packages ({{varsdict.desktop}})':
  cmd.run:
    #- shell: /bin/sh
    - name: |
        for pkgX in {{pkgs_var}} ; do
          apt-get --fix-broken -y install ${pkgX} ;
        done
{% elif grains['os_family']|lower in ['suse', 'redhat', 'mageia', 'netbsd', 'openbsd'] %}
'Install user interface packages ({{varsdict.desktop}})':
  pkg.installed:
    - pkgs: {{pkgs_var.split(' ')}}
    - kwargs:
      # suse zypper .. --ignore-unknown ; redhat dnf .. --skip-broken
      ignore_unknown: True
      #get_extra_options: True
      skip_broken: True
{% else %}
'Install user interface packages ({{varsdict.desktop}})':
  pkg.installed:
    - pkgs: {{pkgs_var.split(' ')}}

  {% for pkgX in pkgs_var.split(' ') %}
'retry failed Install user interface packages ({{varsdict.desktop}}) (loop: {{pkgX}})':
  pkg.installed:
    - name: {{pkgX}}
    - onfail:
      - pkg: 'Install user interface packages ({{varsdict.desktop}})'
  {% endfor %}
{% endif %}

{#{% set out_java = salt['cmd.shell']('java -version || echo ""', shell='/bin/sh') %}
{% if '' != out_java %}#}
{% set found_java = salt['file.find']('/', name='java') %}
{% if [] != found_java %}
  {#{% set out_javahome = salt['cmd.shell']('dirname $(dirname $(realpath $(which java)))', shell='/bin/sh') %}#}
  {% set out_javahome = salt['cmd.shell']('realpath $(which java) | sed "s:/bin/java::"', shell='/bin/sh') %}
  {#
  {% if 'csh' in salt['environ.get']('SHELL') %}
/etc/csh.cshrc:
  file.replace:
    - pattern: '^setenv JAVA_HOME.*'
    - repl: 'setenv JAVA_HOME {{out_javahome}}'
    - append_if_not_found: True
  {% endif %}
  {% if 'bash' in salt['environ.get']('SHELL') %}
/etc/bash.bashrc:
  file.replace:
    - pattern: '^export JAVA_HOME.*'
    - repl: 'export JAVA_HOME={{out_javahome}}'
    - append_if_not_found: True
  {% endif %}
  {% if 'ksh' in salt['environ.get']('SHELL') %}
/etc/ksh.kshrc:
  file.replace:
    - pattern: '^export JAVA_HOME.*'
    - repl: 'export JAVA_HOME={{out_javahome}}'
    - append_if_not_found: True
  {% endif %}
  #}
/etc/profile.d/jdk.sh:
  file.replace:
    - pattern: '^export JAVA_HOME.*'
    - repl: 'export JAVA_HOME={{out_javahome}}'
    - append_if_not_found: True
  {% if grains['kernel']|lower not in ['linux'] %}
/etc/fstab:
  file.replace:
    - pattern: '^fdesc.*'
    - repl: 'fdesc  /dev/fd  fdescfs  rw  0  0'
    - append_if_not_found: True
  {% endif %}
{% endif %}

# conditionally(exists if count > 0) include file
{% if salt['cp.list_master'](prefix=tpldir ~ '/config_' ~ variant ~ '.sls')|count %}
{#include:
  - {{tpldot}}.config_{{variant}}#}
{% include tpldir ~ '/config_' ~ variant ~ '.sls' %}
{% endif %}

{#
Config XDG directories w/ shell script:
  cmd.run:
    #- shell: /bin/sh
    - name: sh /root/init/common/misc_config.sh cfg_xdguserdirs {{varsdict.etcdir_xdg}}
#}

Add directory bin to XDG directories config:
  file.replace:
    - name: '{{varsdict.etcdir_xdg}}/user-dirs.defaults'
    - pattern: '^BIN=.*'
    - repl: 'BIN=bin'

Run xdg-user-dirs-update:
  cmd.run:
    - shell: /bin/sh
    - name: |
        export LANG=en_US.UTF-8 ; export CHARSET=UTF-8
        xdg-user-dirs-update ; chmod 1777 /tmp

{#
Config Xorg touchpad tapping w/ shell script:
  cmd.run:
    #- shell: /bin/sh
    - name: sh /root/init/common/misc_config.sh cfg_xorgtouchpad {{varsdict.xorgconfd_dir}}
#}

{% for confX in ['10-evdev.conf', '40-libinput.conf'] %}
'Turn on Option Tapping {{varsdict.xorgconfd_dir}}/{{confX}}':
  file.line:
    - name: '{{varsdict.xorgconfd_dir}}/{{confX}}'
    - after: 'MatchIsTouchpad.*'
    - mode: ensure
    - match: '.*Option "Tapping" "on".*'
    - content: '       Option "Tapping" "on"'
{% endfor %}

{% if grains.get('init', '')|lower in ['systemd'] %}
Set graphical.target default for systemd:
  cmd.run:
    #- shell: /bin/sh
    - name: systemctl set-default graphical.target
{% endif %}

'Enable user interface related service(s) ({{varsdict.desktop}})':
  service.enabled:
    - names: {{varsdict.distro_pkgs.get("uiservices_enabled_" ~ varsdict.desktop, "").split(' ')}}

{% if grains.get('init', '')|lower in ['systemd'] %}
'Unmask service(s) ({{grains.get("init", "")}})':
  service.unmasked:
    - names: {{varsdict.distro_pkgs.get("uiservices_enabled_" ~ varsdict.desktop, "").split(' ')}}
{% endif %}

'Disable user interface related service(s) ({{varsdict.desktop}})':
  service.disabled:
    - names: {{varsdict.distro_pkgs.get("uiservices_disabled_" ~ varsdict.desktop, "").split(' ')}}

{% if grains.get('init', '')|lower in ['systemd'] %}
'Mask service(s) ({{grains.get("init", "")}})':
  service.masked:
    - names: {{varsdict.distro_pkgs.get("uiservices_disabled_" ~ varsdict.desktop, "").split(' ')}}
{% endif %}

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
