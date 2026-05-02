{% set autoextract = salt['pillar.get']('state1', {}).get('autoextract', 'NO') %}
{% if grains['os_family']|lower == 'freebsd' %}
  {% set uname_m = grains.cpuarch %}
  {% set release = grains.osrelease ~ '-RELEASE' %}
  {#{% if (autoextract|to_bool) %}
    # ['src', 'ports']
    {% for setX in (distrosets | default(['src'])) %}
'Fetch & extract missing distribution components like: {{setX}}.txz':
  archive.extracted:
    - name: /
    - source: 'ftp://ftp.freebsd.org/pub/FreeBSD/releases/{{uname_m}}/{{release}}/{{setX}}.txz'
    - skip_verify: True
    - options: zv
    {% endfor %}
  {% endif %}#}

  {% for setX in (distrosets | default(['src'])) %}
'Fetch, then extract missing distribution components ({{setX}}.txz)':
  file.managed:
    - name: '/tmp/{{setX}}.txz'
    - source: 'ftp://ftp.freebsd.org/pub/FreeBSD/releases/{{uname_m}}/{{release}}/{{setX}}.txz'
    - skip_verify: True
    {% if (autoextract|to_bool) %}
  archive.extracted:
    - name: /
    - source: '/tmp/{{setX}}.txz'
    - options: zv
    {% endif %}
  {% endfor %}
{% elif grains['os_family']|lower == 'netbsd' %}
  {% set uname_m = grains.cpuarch %}
  {% set rel = grains.osrelease %}
  {#{% if (autoextract|to_bool) %}
    # ['xbase', 'xserver', 'xfont', 'xetc']
    {% for setX in (distrosets | default(['xbase'])) %}
'Fetch & extract missing distribution sets like: {{setX}}.tar.xz':
  archive.extracted:
    - name: /
    - source: 'http://cdn.netbsd.org/pub/NetBSD/NetBSD-{{rel}}/{{uname_m}}/binary/sets/{{setX}}.tar.xz'
    - skip_verify: True
    - options: pJ
    {% endfor %}
  {% endif %}#}

  {% for setX in (distrosets | default(['xbase'])) %}
'Fetch, then extract missing distribution sets like: {{setX}}.tar.xz':
  file.managed:
    - name: '/tmp/{{setX}}.tar.xz'
    - source: 'http://cdn.netbsd.org/pub/NetBSD/NetBSD-{{rel}}/{{uname_m}}/binary/sets/{{setX}}.tar.xz'
    - skip_verify: True
    {% if (autoextract|to_bool) %}
  archive.extracted:
    - name: /
    - source: '/tmp/{{setX}}.tar.xz'
    - options: pJ
    {% endif %}
  {% endfor %}
{% elif grains['os_family']|lower == 'openbsd' %}
  {% set arch_s = grains.cpuarch %}
  {% set rel = grains.osrelease %}
  {% set setVer = grains.osrelease|replace('.', '') %}
  {#{% if (autoextract|to_bool) %}
    # ['xbase', 'xserv', 'xfont', 'xshare']
    {% for setX in (distrosets | default(['xbase'])) %}
'Fetch & extract missing distribution sets like: {{setX}}*.tgz':
  archive.extracted:
    - name: /
    - source: 'http://cdn.openbsd.org/pub/OpenBSD/{{rel}}/{{arch_s}}/{{setX}}{{setVer}}.tgz'
    - skip_verify: True
    - options: pz
    {% endfor %}
  {% endif %}#}

  {% for setX in (distrosets | default(['xbase'])) %}
'Fetch, then extract missing distribution sets like: {{setX}}*.tgz':
  file.managed:
    - name: '/tmp/{{setX}}{{setVer}}.tgz'
    - source: 'http://cdn.openbsd.org/pub/OpenBSD/{{rel}}/{{arch_s}}/{{setX}}{{setVer}}.tgz'
    - skip_verify: True
    {% if (autoextract|to_bool) %}
  archive.extracted:
    - name: /
    - source: '/tmp/{{setX}}{{setVer}}.tgz'
    - options: pz
    {% endif %}
  {% endfor %}

  {% if (autoextract|to_bool) %}
sysmerge updates:
  cmd.run:
    #- shell: /bin/sh
    - name: sysmerge
  {% endif %}
{% endif %}
