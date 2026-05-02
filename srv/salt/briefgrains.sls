#grains keys:
{# {% set keys = salt['grains.items']().keys()|list|sort|join(', ') %}
  #test.show_notification:
  #  - name: keys
  #  - text: "[{{keys}}]"
  module.run:
    - grains.ls: #}

{#{% set dict1 = salt['slsutil.merge']({'init': ''}, salt['grains.items']().keys()|zip(salt['grains.items']().values())) %} #}
{#{% set days_uptime = (salt['status.uptime']()['seconds']/(24*60*60))|round(2) %}#}
{% if grains['os_family']|lower in ['openbsd'] %}
  {% set last_boot = salt['cmd.shell']('who | head -n1', shell='/bin/sh') %}
{% else %}
  {% set last_boot = salt['cmd.shell']('who -b', shell='/bin/sh') %}
{% endif %}
brief Salt grains:
{% set state1_items = pillar.get('state1', {}).get('items', 'kernel,kernelrelease,kernelversion,os_family,osrelease,lsb_distrib_id,lsb_distrib_codename,cpuarch,nodename,init,saltversion,pythonversion') %}
{% set dict1 = salt['slsutil.merge']({'init': ''}, salt['grains.item'](*state1_items.split(','))) %}
  #test.show_notification:
  #  - name: 'items'
  #  {#- - text: "{{dict1|map('join', ': ')|sort|list|join(',\\n')}}" #}
  #  - text: "{{dict1|dictsort|map('join', ': ')|list|join(',\\n')}}"
  module.run:
    - test.echo:
      - text: '{{grains['id']}}: (last boot: {{last_boot}})'
    #- grains.items:
    - grains.item: {{state1_items.split(',')}}

{% set timestamp = salt['system.get_system_date_time']('+0000')|strftime('%Y-%m-%d@%H:%M:%S~') %}
'/tmp/salt_briefgrains-{{grains["cpuarch"]}}.txt.{{timestamp}}':
  file.copy:
    - source: '/tmp/salt_briefgrains-{{grains["cpuarch"]}}.txt'
    - user: packer
    - mode: 0644

'/tmp/salt_briefgrains-{{grains["cpuarch"]}}.txt':
  file.managed:
    - user: packer
    - mode: 0644
    - contents: |
        {{grains['id']}}: (last boot: {{last_boot}})
            ----------
    {%- for keyX, valX in dict1.items()|sort %}
            {{keyX}}: {{valX}}
    {%- endfor %}

log entry:
  cmd.run:
    #- shell: /bin/sh
    - name: "logger -s -t user -p user.notice Salt brief grains"
