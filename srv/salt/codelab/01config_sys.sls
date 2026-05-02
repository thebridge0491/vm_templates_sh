{% from tpldir ~ "/map.jinja" import varsdict with context %}
{% set variant = {'artix': 'archlinux', 'arch': 'archlinux'}.get(
     grains['os_family']|lower, grains['os_family'])|lower %}

Ensure /etc/profile.d directory:
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

  # PATH_TO_FX location varies: # try find javafx[-.]fxml*.jar
  #  [/usr/lib/jvm/java-[N]-openjfx|/opt/javafx-sdk-[N]]/lib: Arch Linux, Gluon download
  #  /usr/local/openjfx[N]/lib: FreeBSD
  #  /usr/share/openjfx: Debian
  {# {% set found_jfxjar = salt['file.find']('/usr', name='javafx[-.]fxml.*.jar') %} #}
  {% set out_jfxjar = salt['cmd.shell']('find /usr /opt -name "javafx[-.]fxml*.jar" | head -n1', shell='/bin/sh').split() %}
  {% set path_to_fx = salt['file.dirname'](out_jfxjar[0] | default("/usr/lib/jvm/java-11-openjfx/lib/javafx.fxml.jar")) %}
Fix PATH_TO_FX /etc/profile.d/jdk.sh:
  file.replace:
    - name: /etc/profile.d/jdk.sh
    - pattern: '^export PATH_TO_FX.*'
    - repl: 'export PATH_TO_FX={{path_to_fx}}'
    - append_if_not_found: True
{% endif %}

# conditionally(exists if count > 0) include file
{% if salt['cp.list_master'](prefix=tpldir ~ '/config_' ~ variant ~ '.sls')|count %}
{#include:
  - {{tpldot}}.config_{{variant}}#}
{% include tpldir ~ '/config_' ~ variant ~ '.sls' %}
{% endif %}
