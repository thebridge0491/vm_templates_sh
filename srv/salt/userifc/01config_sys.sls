{% from tpldir ~ "/map.jinja" import varsdict with context %}
{% set variant = {'artix': 'archlinux', 'arch': 'archlinux'}.get(
     grains['os_family']|lower, grains['os_family'])|lower %}

Ensure /etc/profile.d directory exists:
  file.directory:
    - name: /etc/profile.d

{% set etcprofile_exists = salt['file.file_exists']('/etc/profile') %}
{% if not etcprofile_exists %}
Ensure /etc/profile file exists:
  cmd.run:
    - shell: /bin/sh
    - name: |
        if [ ! -e /etc/profile ] ; then
          cat << EOF > /etc/profile ;
        if [ -d /etc/profile.d ] ; then
          for i in /etc/profile.d/*.sh ; do
            if [ -r "${i}" ] ; then
              . "${i}" ;
            fi ;
          done ;
          unset i ;
        fi

        EOF
          chmod +x /etc/profile ;
        fi
{% endif %}

{% set out_java = salt['cmd.shell']('java -version', shell='/bin/sh', ignore_retcode=True) %}
{% if "not found" not in out_java %}
{#{% set found_java = salt['file.find']('/', name='java') %}
{% if [] != found_java %}#}
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

Chmod +x /etc/profile.d/jdk.sh:
  file.managed:
    - name: /etc/profile.d/jdk.sh
    - mode: 0755

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

/etc/profile.d/qt_qpa.sh:
  file.replace:
    - pattern: '^export QT_QPA_PLATFORM.*'
    - repl: 'export QT_QPA_PLATFORM="wayland;xcb"'
    - append_if_not_found: True

Chmod +x /etc/profile.d/qt_qpa.sh:
  file.managed:
    - name: /etc/profile.d/qt_qpa.sh
    - mode: 0755

/etc/profile.d/gdk_backend.sh:
  file.replace:
    - pattern: '^export GDK_BACKEND.*'
    - repl: 'export GDK_BACKEND="wayland;x11"'
    - append_if_not_found: True

Chmod +x /etc/profile.d/gdk_backend.sh:
  file.managed:
    - name: /etc/profile.d/gdk_backend.sh
    - mode: 0755

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
