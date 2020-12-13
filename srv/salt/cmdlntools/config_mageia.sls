{% from tpldir ~ "/map.jinja" import varsdict with context %}

Config dnf install_weak_deps:
  cmd.run:
    #- shell: /bin/sh
    - name: |
        dnf --setopt=install_weak_deps=False config-manager --save
        dnf config-manager --dump | grep -we install_weak_deps

Touch /etc/bash.bashrc:
  file.touch:
    - name: /etc/bash.bashrc

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

Config misc services(ntp, firewall):
  cmd.run:
    #- shell: /bin/sh
    - name: |
        ntpd -u ntp:ntp ; ntpq -p ; sleep 3
        #sh /root/init/common/linux/firewall/shorewall/config_shorewall.sh config_shorewall allow
        #drakfirewall ; cat /etc/shorewall/rules.drakx ; sleep 5

        shorewall save ; shorewall6 save #; shorewall restore ; shorewall6 restore

#/etc/sudoers:
#  file.line:
#    - after: 'Defaults.*env_reset.*'
#    - mode: ensure
#    - match: 'Defaults.*secure_path=.*'
#    - content: 'Defaults    secure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"'
