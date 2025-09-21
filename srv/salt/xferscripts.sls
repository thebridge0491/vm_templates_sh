{% set variant = {'artix': 'archlinux', 'arch': 'archlinux'}.get(
     grains['os_family']|lower, grains['os_family'])|lower %}

copy local scripts tarball to remote:
  file.managed:
    - name: /tmp/scripts.tar
    - source: salt://tmp/scripts_{{variant}}.tar

{%- if salt['file.file_exists']('/tmp/scripts.tar') %}
  {% for pathX in ['/tmp/init', '/tmp/scripts', '/root/init', '/root/scripts'] %}
'Remove old script {{pathX}}':
  file.absent:
    - name: {{pathX}}
  {% endfor %}

/tmp:
  archive.extracted:
    - source: /tmp/scripts.tar

/tmp/scripts:
  file.rename:
    - source: /tmp/{{variant}}

  cmd.run:
    #- shell: /bin/sh
    - name: chown -R $(id -un):$(id -gn) /tmp/init /tmp/scripts

  {% for item in {'src': '/tmp/init', 'dest': '/root/init'}
     , {'src': '/tmp/scripts', 'dest': '/root/scripts'} %}
{{item.dest}}:
  file.copy:
    - source: {{item.src}}
  {% endfor %}

#/tmp/scripts.tar:
#  file.absent
{%- endif %}
