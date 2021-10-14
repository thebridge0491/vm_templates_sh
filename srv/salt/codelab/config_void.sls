{% from tpldir ~ "/map.jinja" import varsdict with context %}

Touch /etc/bash.bashrc:
  file.touch:
    - name: /etc/bash.bashrc

/etc/bash.bashrc:
  file.replace:
    - pattern: '^export JAVA_HOME.*'
    - repl: 'export JAVA_HOME={{varsdict.distro_pkgs.default_java_home}}'
    - append_if_not_found: True

{{varsdict.distro_pkgs.default_java_home}}:
  file.directory

{{varsdict.distro_pkgs.default_java_home.replace('"', '')+'/release'}}:
  file.replace:
    - pattern: '^JAVA_VERSION.*'
    - repl: 'JAVA_VERSION={{varsdict.distro_pkgs.default_java_version}}'
    - append_if_not_found: True

'(variant: {{grains['os_family']|lower}}) Install xterm,Xauth pkgs for X11 forwarding over SSH':
  pkg.installed:
    - pkgs: ['xauth', 'xterm']
