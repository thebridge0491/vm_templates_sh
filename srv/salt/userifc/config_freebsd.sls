{% from tpldir ~ "/map.jinja" import varsdict with context %}

{% for item in {'rexp': '^kern.vty=.*', 'line': 'kern.vty=vt'},
    {'rexp': '^hw.psm.synaptics_support=.*', 'line': 'hw.psm.synaptics_support="1"'} %}
'Change /boot/loader.conf {{item.rexp}} to {{item.line}}':
  file.replace:
    - name: /boot/loader.conf
    - pattern: '{{item.rexp}}'
    - repl: '{{item.line}}'
{% endfor %}

touch /etc/profile.conf:
  file.touch:
    - name: /etc/profile.conf
{% for item in {'rexp': '^LANG=.*', 'line': 'LANG=en_US.UTF-8 ; export LANG'},
    {'rexp': '^CHARSET=.*', 'line': 'CHARSET=UTF-8 ; export CHARSET'} %}
'Change /etc/profile.conf {{item.rexp}} to {{item.line}}':
  file.replace:
    - name: /etc/profile.conf
    - pattern: '{{item.rexp}}'
    - repl: '{{item.line}}'
{% endfor %}
