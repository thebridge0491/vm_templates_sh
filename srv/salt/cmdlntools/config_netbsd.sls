{% from tpldir ~ "/map.jinja" import varsdict with context %}

Fetch missing distribution sets (xbase):
  cmd.run:
    - shell: /bin/sh
    - name: |
        arch=$(uname -m) ; rel=$(sysctl -n kern.osrelease)
        cd /tmp
        for setX in xbase ; do
          ftp http://cdn.netbsd.org/pub/NetBSD/NetBSD-${rel}/${arch}/binary/sets/${setX}.tar.xz ;
          tar -C / -xpJf ${setX}.tar.xz ;
        done

{% for item in ['ntpd', 'dbus', 'freshclamd', 'clamd', 'avahidaemon', 'cupsd'] %}
Xfer /usr/pkg/share/examples/rc.d/{{item}} /etc/rc.d/{{item}}:
  cmd.run:
    - name: cp -R /usr/pkg/share/examples/rc.d/{{item}} /etc/rc.d/{{item}}
{% endfor %}

/var/run/dbus:
  file.directory

{% for item in ['ntpd', 'pf', 'pflogd', 'dbus', 'avahidaemon', 'rpcbind',
     'nfsd', 'mountd', 'cupsd', 'lpd'] %}
'Change {{item}}=.* to {{item}}=YES':
  file.replace:
    - name: /etc/rc.conf
    - pattern: '^{{item}}=.*'
    - repl: '{{item}}=YES'
    - append_if_not_found: True
{% endfor %}

/etc/csh.cshrc:
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
        #/usr/sbin/ntpd -u ntp:ntp ; /usr/sbin/ntpq -p
        /usr/sbin/ntpdate -v -u -b us.pool.ntp.org

        /sbin/pfctl -d
        env sed_inplace="sed -i" sh /root/init/common/bsd/firewall/pf/pfconf.sh config_pf allow > /etc/pf.conf.new
        if [ ! -e /etc/pf.conf ] ; then cp /etc/pf.conf.new /etc/pf.conf ; fi
        sed -i '/icmp6 / s|icmp6 |ipv6-icmp |' /etc/pf/outallow_in_allow.rules
        sed -i '/icmp6 / s|icmp6 |ipv6-icmp |' /etc/pf/outdeny_out_allow.rules
        /sbin/pfctl -vf /etc/pf.conf ; /sbin/pfctl -s info ; /sbin/pfctl -s rules -a '*'

        #cd /usr/bin
        #for file1 in lp lpq lpr lprm ; do
        #  if [ -e ${file1} ] ; then
        #    mv ${file1} ${file1}.old ;
        #  fi ;
        #  ln -s /usr/local/bin/${file1} ${file1} ;
        #done

#cups:
#  group.present:
#    - addusers: [root]
