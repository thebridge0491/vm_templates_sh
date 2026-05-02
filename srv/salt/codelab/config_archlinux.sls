# for runit service ops w/ Ansible,Saltstack
{% if 'runit' == grains['init'] %}
  {% for item in {'srcX': '/etc/runit/sv', 'destX': '/etc/sv'}
     , {'srcX': '/run/runit/service', 'destX': '/var/service'} %}
     #, {'srcX': '/etc/runit/runsvdir/default', 'destX': '/var/service'}
'Symlink {{item.srcX}} to {{item.destX}}':
  file.symlink:
    - name: {{item.destX}}
    - target: {{item.srcX}}
  {% endfor %}
{% endif %}
