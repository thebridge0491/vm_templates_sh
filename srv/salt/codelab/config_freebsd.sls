{% from tpldir ~ "/map.jinja" import varsdict with context %}

/etc/csh.cshrc:
  file.replace:
    - pattern: '^setenv JAVA_HOME.*'
    - repl: 'setenv JAVA_HOME {{varsdict.distro_pkgs.default_java_home}}'
    - append_if_not_found: True

/etc/fstab:
  file.replace:
    - pattern: '^fdesc.*'
    - repl: 'fdesc  /dev/fd  fdescfs  rw  0  0'
    - append_if_not_found: True
