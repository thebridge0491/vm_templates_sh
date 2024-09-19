{% from tpldir ~ "/map.jinja" import varsdict with context %}

/etc/csh.cshrc:
  file.replace:
    - pattern: '^setenv JAVA_HOME.*'
    - repl: 'setenv JAVA_HOME {{varsdict.distro_pkgs.default_java_home}}'
    - append_if_not_found: True

/etc/fstab:
  file.replace:
    - pattern: '^fdesc.*'
    - repl: 'fdesc  /dev/fd  fdescfs  rw  0  0'
    - append_if_not_found: True

Config misc services(ntp, firewall):
  cmd.run:
    - shell: /bin/sh
    - name: |
        #ntpd -u ntp:ntp ; ntpq -p
        ntpdate -v -u -b us.pool.ntp.org

        pfctl -d
        sh /root/init/common/bsd/firewall/pf/pfconf.sh config_pf allow > /etc/pf.conf.new
        if [ ! -e /etc/pf.conf ] ; then cp /etc/pf.conf.new /etc/pf.conf ; fi
        pfctl -vf /etc/pf.conf ; pfctl -s info ; pfctl -s rules -a '*'

        cd /usr/bin
        for file1 in lp lpq lpr lprm ; do
          if [ -e ${file1} ] ; then
            mv ${file1} ${file1}.old ;
          fi ;
          ln -s /usr/local/bin/${file1} ${file1} ;
        done

config devfs:
  sysrc.managed:
    - name: devfs_system_ruleset
    - value: devfsrules_system

cups:
  group.present:
    - gid: 193
    - system: True
    - addusers: [root]

touch /etc/devfs.rules:
  file.touch:
    - name: /etc/devfs.rules
config /etc/devfs.rules:
  file.blockreplace:
    - name: /etc/devfs.rules
    - content: |
        [devfsrules_system=10]
        add path 'unlpt*' group cups mode 0660
        add path 'ulpt*' group cups mode 0660
        add path 'lpt*' group cups mode 0660

        #NOTE, find USB device correspond to printer: dmesg | grep -e ugen
        #add path 'usb/X.Y.Z' group cups mode 0660
    - append_if_not_found: True
