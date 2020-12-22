{% from tpldir ~ "/map.jinja" import varsdict with context %}

Fetch missing distribution sets (xbase, xserver, xfont, xetc):
  cmd.run:
    - shell: /bin/sh
    - name: |
        arch=$(uname -m) ; rel=$(sysctl -n kern.osrelease)
        cd /tmp
        for setX in xbase xserver xfont xetc ; do
          ftp http://cdn.netbsd.org/pub/NetBSD/NetBSD-${rel}/${arch}/binary/sets/${setX}.tar.xz ;
          tar -C / -xpJf ${setX}.tar.xz ;
        done

/var/run/dbus:
  file.directory

/var/run/xdm:
  file.directory

{# {% for item in ['dbus', 'wsmoused', 'xdm'] %}
'Change /etc/rc.conf ^{{item}}=.* to {{item}}=YES':
  file.replace:
    - name: /etc/rc.conf
    - pattern: '^{{item}}=.*'
    - repl: '{{item}}=YES'
    - append_if_not_found: True
{% endfor %} #}

touch /etc/X11/xorg.conf:
  file.touch:
    - name: /etc/X11/xorg.conf
/etc/X11/xorg.conf:
  file.blockreplace:
    - content:
        Section "Device"
          Identifier "Card0"
          Driver "wsfb"
        EndSection
    - append_if_not_found: True

touch /root/.xinitrc:
  file.touch:
    - name: /root/.xinitrc
{% for item in {'rexp': '^export XDG_DATA_DIRS=.*',
    'line': 'export XDG_DATA_DIRS=/usr/pkg/share'},
    {'rexp': '^export XDG_CONFIG_DIRS=.*',
    'line': 'export XDG_CONFIG_DIRS=/usr/pkg/etc/xdg'} %}
'Change /root/.xinitrc {{item.rexp}} to {{item.line}}':
  file.replace:
    - name: /root/.xinitrc
    - pattern: '{{item.rexp}}'
    - repl: '{{item.line}}'
    - append_if_not_found: True
{% endfor %}

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
        /usr/sbin/groupadd -g 81 dbus || true
        /usr/sbin/useradd -c 'System message bus' -u 81 -g dbus -d '/' -s /usr/bin/false dbus || true
        mkdir -p /var/db/dbus /var/lib/xdm /usr/pkg/etc/xdm /usr/pkg/etc/xdg
        cp -R /usr/pkg/share/examples/xdm /usr/pkg/etc/
        cp -R /usr/pkg/share/examples/xfce4 /usr/pkg/etc/xdg/ || true
        cp -R /usr/pkg/share/examples/lxqt /usr/pkg/etc/xdg/ || true

        for dirX in dbus xdm ; do
          cp -R /usr/pkg/share/examples/rc.d/$dirX /etc/rc.d/$dirX ;
        done

        ln -s /root/.xinitrc /root/.xsession
        cp /root/.xinitrc /home/packer/.xinitrc
        chown packer:$(id -gn packer) /home/packer/.xinitrc
        (cd /home/packer ; ln -s /home/packer/.xinitrc .xsession)

        # set video resolution ? gop 6: 1024x768x32
        sed -i 's|;boot|;gop 6;boot|g' /boot.cfg
