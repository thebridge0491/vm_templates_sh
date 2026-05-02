snapshot:
  {% set dateutc = salt['system.get_system_date']('+0000')|strftime('%Y%m%d') %}
  {% if '' != salt['pillar.get']('state1', {}).get('snapshot_name', '') %}
    {% set snapshot_name = salt['pillar.get']('state1').get('snapshot_name') %}
  {% endif %}
  {% set dev_root = salt['mount.get_device_from_path']('/') %}
  {#{% set voltypeX = (salt['disk.fstype'](dev_root|string) or 'zfs').split() %}#}
  {#{% set df_found = salt['cmd.shell']('df -lhT / | sed -n "s/.*\(btrfs\).*$/\1/p ; s/.*\([fuz]fs\).*$/\1/p"', shell='/bin/sh') %}#}
  {% set df_found = salt['cmd.shell']('df -lhT / | grep -e "btrfs" -e "[fuz]fs"', shell='/bin/sh') %}
  {% set voltypeX = df_found.split()[1] %}
  {#{% if 'zfs' == voltypeX and grains['os_family']|lower in ['freebsd'] %}#}
  {% if 'zfs' == voltypeX and grains['kernel']|lower in ['freebsd', 'linux'] %}
  {#zfs.snapshot_present:
    - name: "{{dev_root}}@{{snapshot_name | default('snap1-'+dateutc)}}"
  module.run:
    #}{#- zfs.snapshot:
      - snapshot: "{{dev_root}}@{{snapshot_name | default('snap1-'+dateutc)}}"#}{#
    - zfs.list:
      - type: snapshot#}
  cmd.run:
    #- shell: /bin/sh
    - name: |
        zfs snapshot {{dev_root}}@{{snapshot_name | default('snap1-'+dateutc)}}

        zfs list -t snapshot
  {% elif 'btrfs' == voltypeX and grains['kernel']|lower in ['linux'] %}
  {#module.run:
    - btrfs.subvolume_snapshot:
      - source: /
      - dest: /.snapshots
      - name: "{{snapshot_name | default('snap1-'+dateutc)}}"
    #- btrfs.subvolume_list:
    #  - path: /
    #  - snapshots: True#}
  cmd.run:
    #- shell: /bin/sh
    - name: |
        btrfs subvolume snapshot / /.snapshots/{{snapshot_name | default('snap1-'+dateutc)}}
  cmd.run:
    #- shell: /bin/sh
    - name: |
        #btrfs filesystem show ; fstrim -av
        btrfs subvolume list -s / ; fstrim -av
  {#-
  {% elif 'ufs' == voltypeX and grains['kernel']|lower in ['freebsd'] %}
  cmd.run:
    #- shell: /bin/sh
    - name: |
        mksnap_ffs / /.snap/{{snapshot_name | default('snap1-'+dateutc)}}

        find / -flags snapshot ; snapinfo /
  {% elif grains['kernel']|lower in ['linux'] %}
    {#{% set lsblk_found = salt['cmd.shell']('lsblk | grep -e "/[ ]*$" | sed -n "s/.*\(lvm\).*$/\1/p"', shell='/bin/sh') %}#}
    {% set lsblk_found = salt['cmd.shell']('lsblk -nlpo name,type,mountpoint | grep -e "/[ ]*$" || true', shell='/bin/sh') %}
    {% set voltypeX = df_found.split()[1] or lsblk_found.split()[1] %}
    {% if 'lvm' == voltypeX %}
      {% set grp_lv = dev_root.split('/')[3] %}
  {#module.run:
    - lvm.lvcreate:
      - lvname: "{{snapshot_name | default('snap1-'+dateutc)}}"
      - vgname: "{{grp_lv.split('-')[0]}}"
      - snapshot: "{{grp_lv.split('-')[1]}}"
      - size: 2G#}
  cmd.run:
    #- shell: /bin/sh
    - name: |
        lvcreate --snapshot --size 2G --name {{snapshot_name | default('snap1-'+dateutc)}} {{grp_lv.replace('-', '/')}}
  cmd.run:
    #- shell: /bin/sh
    - name: lvs -S 'lv_attr =~ ^s' || lvs ; fstrim -av
    {% endif %}
  #}
  {% endif %}
