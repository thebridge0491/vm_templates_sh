{% set variant = {'artix': 'archlinux', 'arch': 'archlinux',
     'centos stream': 'redhat'}.get(grains['os_family']|lower,
     grains['os_family'])|lower %}

{%- if salt['file.file_exists']('/tmp/scripts.tar') %}
remove old dirs:
  file.absent:
    - names: ['/tmp/init', '/tmp/scripts', '/root/init', '/root/scripts']

/tmp:
  archive.extracted:
    - source: /tmp/scripts.tar

/tmp/scripts:
  file.rename:
    - source: /tmp/{{variant}}

{% for item in {'src': '/tmp/init', 'dest': '/root/init'},
   {'src': '/tmp/scripts', 'dest': '/root/scripts'} %}
{{item.dest}}:
  file.copy:
    - source: {{item.src}}
{% endfor %}

#/tmp/scripts.tar:
#  file.absent
{%- endif %}
