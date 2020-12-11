{% from tpldir ~ "/map.jinja" import varsdict with context %}

Config zypp solver.onlyRequires & zypper installRecommends:
  cmd.run:
    #- shell: /bin/sh
    - name: |
        sed -i 's|.*solver.onlyRequires.*=.*|solver.onlyRequires = true|' \
          /etc/zypp/zypp.conf
        sed -i 's|.*installRecommends.*=.*|installRecommends = no|' \
          /etc/zypp/zypper.conf

Remove netcat-openbsd:
  pkg.removed:
    - pkgs: [netcat-openbsd]

Install patterns:
  pkg.installed:
    - pkgs: ['+pattern:enhanced_base', '+pattern:apparmor', '+pattern:sw_management']

/etc/bash.bashrc:
  file.replace:
    - pattern: '^export JAVA_HOME.*'
    - repl: 'export JAVA_HOME={{varsdict.distro_pkgs.default_java_home}}'
    - append_if_not_found: True

{{varsdict.distro_pkgs.default_java_home}}:
  file.directory

{{varsdict.distro_pkgs.default_java_home.replace('"', '')+'/release'}}:
  file.replace:
    - pattern: '^JAVA_VERSION.*'
    - repl: 'JAVA_VERSION={{varsdict.distro_pkgs.default_java_version}}'
    - append_if_not_found: True

Config misc services(firewall):
  cmd.run:
    #- shell: /bin/sh
    - name: |
        ntpd -u ntp:ntp ; ntpq -p ; sleep 3
        sh /root/init/common/linux/firewall/firewalld/config_firewalld.sh cmds_firewalld allow

        #yast firewall services add zone=EXT service=service:avahi
        firewall-cmd --zone=public --permanent --add-service=mdns

#/etc/sudoers:
#  file.line:
#    - after: 'Defaults.*env_reset.*'
#    - mode: ensure
#    - match: 'Defaults.*secure_path=.*'
#    - content: 'Defaults    secure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"'
