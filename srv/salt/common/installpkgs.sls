{% if grains['os_family']|lower in ['pclinuxos'] %}
'{{name_task | default("install packages")}}':
  cmd.run:
    #- shell: /bin/sh
    - name: |
        for pkgX in {{pkgs_var | default('pkgUnknown nano pkgMissing zip')}} ; do
          apt-get --fix-broken -y install ${pkgX} ;
        done
{% elif grains['os_family']|lower in ['suse', 'redhat', 'mageia', 'netbsd', 'openbsd'] %}
'{{name_task | default("install packages")}}':
  pkg.installed:
    - pkgs: {{(pkgs_var | default('pkgUnknown nano pkgMissing zip')).split(' ')}}
    - kwargs:
      # arch pacman .. --needed --noconfirm
      needed: True
      noconfirm: True
      # suse zypper .. --ignore-unknown ; redhat dnf .. --skip-broken
      ignore_unknown: True
      #get_extra_options: True
      skip_broken: True
{% else %}
'{{name_task | default("install packages")}}':
  pkg.installed:
    - pkgs: {{(pkgs_var | default('pkgUnknown nano pkgMissing zip')).split(' ')}}

  {% for pkgX in (pkgs_var | default('pkgUnknown nano pkgMissing zip')).split(' ') %}
'retry failed {{name_task | default("install packages")}} ({{pkgX}})':
  pkg.installed:
    - name: {{pkgX}}
    # arch pacman .. --needed --noconfirm
    - needed: True
    - noconfirm: True
    - onfail:
      - pkg: '{{name_task | default("install packages")}}'
  {% endfor %}
{% endif %}
