/usr/local/etc/X11/xorg.conf.d:
  file.directory

{% for confX in ['10-evdev.conf', '40-libinput.conf'] %}
'Copy orig Xorg config files ({{confX}})':
  cmd.run:
    #- shell: /bin/sh
    - name: cp -an /usr/local/share/X11/xorg.conf.d/{{confX}} /usr/local/etc/X11/xorg.conf.d/
{% endfor %}

{% for item in {'flagX': 'wpa_supplicant_progam', 'valX': '/usr/local/sbin/wpa_supplicant'}
   , {'flagX': 'kld_list', 'valX': '+= i915kms'} %}
   # kld_list+=i915kms # i915kms | amdgpu
'sysrc config {{item.flagX}}':
  sysrc.managed:
    - name: {{item.flagX}}
    - value: {{item.valX}}
{% endfor %}

{% for item in {'rexp': '^kern.vty=.*', 'line': 'kern.vty=vt'}
   , {'rexp': '^hw.psm.synaptics_support=.*', 'line': 'hw.psm.synaptics_support="1"'} %}
'Change /boot/loader.conf {{item.rexp}} to {{item.line}}':
  file.replace:
    - name: /boot/loader.conf
    - pattern: '{{item.rexp}}'
    - repl: '{{item.line}}'
    - append_if_not_found: True
{% endfor %}

touch /etc/profile.conf:
  file.touch:
    - name: /etc/profile.conf
{% for item in {'rexp': '^LANG=.*', 'line': 'LANG=en_US.UTF-8 ; export LANG'}
   , {'rexp': '^CHARSET=.*', 'line': 'CHARSET=UTF-8 ; export CHARSET'} %}
'Change /etc/profile.conf {{item.rexp}} to {{item.line}}':
  file.replace:
    - name: /etc/profile.conf
    - pattern: '{{item.rexp}}'
    - repl: '{{item.line}}'
    - append_if_not_found: True
{% endfor %}

{#
# /usr/local/etc/X11/xorg.conf.d/20-[intel|radeon|scfb].conf
/usr/local/etc/X11/xorg.conf.d/20-intel.conf:
  file.blockreplace:
    - content: |
        Section "Device"
          Identifier "Card0"
          Driver "intel" # intel | radeon | scfb
          #BusID "PCI:0:2:0"
        EndSection
    - append_if_not_found: True
#}
