{% set pkgs_spacesep = 'pkgUnknown nano pkgMissing zip' %}
{% set pkgs_list = 'pkgUnknown nano pkgMissing zip'.split() %}
{% if grains['os_family']|lower in ['pclinuxos'] %}
install nano:
  cmd.run:
    #- shell: /bin/sh
    - name: |
        for pkgX in {{pkgs_spacesep}} ; do
          apt-get --fix-broken -y install ${pkgX} ;
        done
{% elif grains['os_family']|lower in ['suse', 'redhat', 'mageia', 'netbsd', 'openbsd'] %}
install nano:
  pkg.installed:
    - pkgs: {{pkgs_list}}
    - kwargs:
      # suse zypper .. --ignore-unknown ; redhat dnf .. --skip-broken
      ignore_unknown: True
      #get_extra_options: True
      skip_broken: True
{% else %}
install nano:
  pkg.installed:
    - pkgs: {{pkgs_list}}

  {% for pkgX in pkgs_list %}
'retry failed install nano ({{pkgX}})':
  pkg.installed:
    - name: {{pkgX}}
    - onfail:
      - pkg: 'install nano'
  {% endfor %}
{% endif %}
