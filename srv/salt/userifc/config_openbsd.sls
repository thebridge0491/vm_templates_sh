{% from tpldir ~ "/map.jinja" import varsdict with context %}

Fetch missing distribution sets (xbase*, xserv*, xfont*, xshare*) & sysmerge updates:
  cmd.run:
    - shell: /bin/sh
    - name: |
        arch=$(arch -s) ; rel=$(sysctl -n kern.osrelease)
        setVer=$(echo ${rel} | tr '.' '\0')
        cd /tmp
        for setX in xbase xserv xfont xshare ; do
          ftp http://cdn.openbsd.org/pub/OpenBSD/${rel}/${arch}/${setX}${setVer}.tgz ;
          tar -C / -xpzf ${setX}${setVer}.tgz ;
        done
        sysmerge

touch /etc/rc.local:
  file.touch:
    - name: /etc/rc.local
'Change /etc/rc.local ^export XDG_CONFIG_HOME=.* to export XDG_CONFIG_HOME=/etc/xdg':
  file.replace:
    - name: /etc/rc.local
    - pattern: '^export XDG_CONFIG_HOME=.*'
    - repl: 'export XDG_CONFIG_HOME=/etc/xdg'
    - append_if_not_found: True

touch /etc/sysctl.conf:
  file.touch:
    - name: /etc/sysctl.conf
'Change /etc/sysctl.conf ^machdep.allowaperture=.* to machdep.allowaperture=2':
  file.replace:
    - name: /etc/sysctl.conf
    - pattern: '^machdep.allowaperture=.*'
    - repl: 'machdep.allowaperture=2'
    - append_if_not_found: True

touch /root/.xinitrc:
  file.touch:
    - name: /root/.xinitrc
{% if varsdict.desktop in ['xfce'] %}
'Config /root/.xinitrc for {{varsdict.desktop}}':
  file.replace:
    - name: /root/.xinitrc
    - pattern: '^ck-launch-session.*'
    - repl: 'ck-launch-session dbus-launch --exit-with-session startxfce4'
    - append_if_not_found: True
{% endif %}

{% if varsdict.desktop in ['lxqt'] %}
'Config /root/.xinitrc for {{varsdict.desktop}}':
  file.replace:
    - name: /root/.xinitrc
    - pattern: '^ck-launch-session.*'
    - repl: 'ck-launch-session dbus-launch --exit-with-session startlxqt'
    - append_if_not_found: True
{% endif %}

Misc config for user interface:
  cmd.run:
    - shell: /bin/sh
    - name: |
        ln -s /root/.xinitrc /root/.xsession
        cp /root/.xinitrc /home/packer/.xinitrc
        chown packer:$(id -gn packer) /home/packer/.xinitrc
        (cd /home/packer ; ln -s /home/packer/.xinitrc .xsession)
