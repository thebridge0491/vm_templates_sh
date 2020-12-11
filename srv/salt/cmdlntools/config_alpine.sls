{% from tpldir ~ "/map.jinja" import varsdict with context %}

Touch /etc/skel/.bashrc:
  file.touch:
    - name: /etc/skel/.bashrc

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
        sh /root/init/common/linux/firewall/nftables/config_nftables.sh cmds_nftables allow

#/etc/sudoers:
#  file.line:
#    - after: 'Defaults.*env_reset.*'
#    - mode: ensure
#    - match: 'Defaults.*secure_path=.*'
#    - content: 'Defaults    secure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"'
