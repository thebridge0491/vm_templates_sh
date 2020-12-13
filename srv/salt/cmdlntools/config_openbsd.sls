{% from tpldir ~ "/map.jinja" import varsdict with context %}

Fetch missing distribution sets (xbase*) & sysmerge updates:
  cmd.run:
    - shell: /bin/sh
    - name: |
        arch=$(arch -s) ; rel=$(sysctl -n kern.osrelease)
        setVer=$(echo $rel | tr '.' '\0')
        cd /tmp
        for setX in xbase ; do
          ftp http://cdn.openbsd.org/pub/OpenBSD/${rel}/${arch}/${setX}${setVer}.tgz ;
          tar -C / -xpzf ${setX}${setVer}.tgz ;
        done
        sysmerge

/etc/ksh.kshrc:
  file.replace:
    - pattern: '^export JAVA_HOME.*'
    - repl: 'export JAVA_HOME={{varsdict.distro_pkgs.default_java_home}}'
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
        env sed_inplace="sed -i" sh /root/init/common/bsd/firewall/pf/pfconf.sh config_pf allow > /etc/pf.conf.new
        if [ ! -e /etc/pf.conf ] ; then cp /etc/pf.conf.new /etc/pf.conf ; fi
        pfctl -vf /etc/pf.conf ; pfctl -s info ; pfctl -s rules -a '*'

        #cd /usr/bin
        #for file1 in lp lpq lpr lprm ; do
        #  if [ -e $file1 ] ; then
        #    mv $file1 $file1.old ;
        #  fi ;
        #  ln -s /usr/local/bin/$file1 $file1 ;
        #done

#cups:
#  group.present:
#    - addusers: [root]
