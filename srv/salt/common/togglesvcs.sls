{% if grains.get('init', '')|lower in ['systemd'] %}
'Unmask {{name_task | default('toggle service(s)')}} ({{grains.get('init', '')}})':
  service.unmasked:
    - names: {{(svcs_enabled | default('')).split(' ')}}
{% endif %}

'Enable {{name_task | default('toggle service(s)')}} ({{grains.get('init', '')}})':
  service.enabled:
    - names: {{(svcs_enabled | default('')).split(' ')}}

'Disable {{name_task | default('toggle service(s)')}} ({{grains.get('init', '')}})':
  service.disabled:
    - names: {{(svcs_disabled | default('')).split(' ')}}

{% if grains.get('init', '')|lower in ['systemd'] %}
'Mask {{name_task | default('toggle service(s)')}} ({{grains.get('init', '')}})':
  service.masked:
    - names: {{(svcs_disabled | default('')).split(' ')}}
{% endif %}
