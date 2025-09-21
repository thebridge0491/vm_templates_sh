{#
#Config nsswitch hosts mdns w/ shell script:
#  cmd.run:
#    #- shell: /bin/sh
#    - name: sh /root/init/common/misc_config.sh cfg_nsswitch_mdns
#}

{% set nsswitch_exists = salt['file.file_exists']('/etc/nsswitch.conf') %}
{% if nsswitch_exists %}
{#'Add hosts: .. mdns /etc/nsswitch.conf':
  file.replace:
    - name: /etc/nsswitch.conf
    - pattern: 'files dns'
    - repl: 'files mdns_minimal [NOTFOUND=return] dns'#}

  {% set nsswitch_stat = salt['file.stats']('/etc/nsswitch.conf') %}
  {% set ymd = nsswitch_stat['mtime']|strftime('%Y%m%d') %}
'Comment old hosts: line /etc/nsswitch.conf':
  file.replace:
    - name: /etc/nsswitch.conf
    - pattern: '^hosts:(.*)$'
    - repl: '#(old {{ymd}}) hosts:\1'

'Add hosts: .. mdns /etc/nsswitch.conf':
  file.replace:
    - name: /etc/nsswitch.conf
    - pattern: '^(#\\(old {{ymd}}\\) hosts:.*)$'
    - repl: '\1\nhosts:\t\tfiles mdns_minimal [NOTFOUND=return] dns'
{% endif %}

{#
#Config sudo nopasswd w/ shell script:
#  cmd.run:
#    #- shell: /bin/sh
#    - name: sh /root/init/common/misc_config.sh cfg_sudo_nopasswd {{varsdict.sudoersd_dir}}
#}

'{{varsdict.sudoersd_dir}}':
  file.directory

{% if variant in ['debian'] %}
  {% for item in {'rexp': '^[^#].*requiretty'
     , 'line': '#Defaults:%sudo !requiretty'}
     , {'rexp': '^.*%sudo.*ALL.*NOPASSWD.*'
     , 'line': '%sudo ALL=(ALL:ALL) NOPASSWD: ALL'} %}
'Change {{item.rexp}} to {{item.line}}':
  file.replace:
    - name: {{varsdict.sudoersd_dir ~ "/99_sudonopasswd"}}
    - pattern: '{{item.rexp}}'
    - repl: '{{item.line}}'
  {% endfor %}
{% else %}
  {% for item in {'rexp': '^[^#].*requiretty'
     , 'line': '#Defaults:%wheel !requiretty'}
     , {'rexp': '^.*%wheel.*ALL.*NOPASSWD.*'
     , 'line': '%wheel ALL=(ALL:ALL) NOPASSWD: ALL'} %}
'Change {{item.rexp}} to {{item.line}}':
  file.replace:
    - name: {{varsdict.sudoersd_dir ~ "/99_wheelnopasswd"}}
    - pattern: '{{item.rexp}}'
    - repl: '{{item.line}}'
  {% endfor %}
{% endif %}

{#
#Config history-search in inputrc w/ shell script:
#  cmd.run:
#    #- shell: /bin/sh
#    - name: sh /root/init/common/misc_config.sh cfg_inputrc_histsearch
#}

{% if grains['kernel']|lower in ['linux'] %}
touch /etc/skel/.inputrc:
  file.touch:
    - name: /etc/skel/.inputrc

/etc/skel/.inputrc:
  file.blockreplace:
    - content: |
        "\e[A": history-search-backward
        "\e[B": history-search-forward
    - append_if_not_found: True
{% endif %}

{#
#Check clamav w/ shell script:
#  cmd.run:
#    #- shell: /bin/sh
#    - name: sh /root/init/common/misc_config.sh check_clamav

#/tmp/eicar.com.txt:
#  file.managed:
#    - source: https://secure.eicar.org/eicar.com.txt
#
#Check clamav:
#  cmd.run:
#    #- shell: /bin/sh
#    - name: |
#        freshclam --verbose ; freshclam --list-mirrors
#        clamscan --verbose /tmp/eicar.com.txt
#        clamscan --recursive /tmp ; rm /tmp/eicar.com.txt
#}

{#
#Config history-search in inputrc w/ shell script:
#  cmd.run:
#    #- shell: /bin/sh
#    - name: sh /root/init/common/misc_config.sh cfg_sshd {{varsdict.skeldir_ssh}}
#}

/etc/ssh/sshd_config.d:
  file.directory

/etc/ssh/sshd_config:
  file.replace:
    - pattern: '^.*Include /etc/ssh/sshd_config.d/\*.conf.*'
    - repl: 'Include /etc/ssh/sshd_config.d/*.conf'
    - append_if_not_found: True

touch /etc/ssh/sshd_config.d/99-rootlogin.conf:
  file.touch:
    - name: /etc/ssh/sshd_config.d/99-login.conf

/etc/ssh/sshd_config.d/99-rootlogin.conf:
  file.replace:
    - pattern: '^.*PermitRootLogin.*'
    - repl: 'PermitRootLogin no'
    - append_if_not_found: True

touch /etc/ssh/sshd_config.d/99-custom.conf:
  file.touch:
    - name: /etc/ssh/sshd_config.d/99-custom.conf

/etc/ssh/sshd_config.d/99-custom.conf:
  file.blockreplace:
    - content: |
        UseDNS no
        GSSAPIAuthentication no
        HostKeyAlgorithms ssh-ed25519-cert-v01@openssh.com,rsa-sha2-512-cert-v01@openssh.com,rsa-sha2-256-cert-v01@openssh.com,ssh-ed25519,rsa-sha2-512,rsa-sha2-256
        PubkeyAcceptedKeyTypes ssh-ed25519-cert-v01@openssh.com,rsa-sha2-512-cert-v01@openssh.com,rsa-sha2-256-cert-v01@openssh.com,ssh-ed25519,rsa-sha2-512,rsa-sha2-256

        HostKey /etc/ssh/ssh_host_ed25519_key
        HostKey /etc/ssh/ssh_host_rsa_key

        TrustedUserCAKeys /etc/ssh/sshca-id_rsa.pub
        RevokedKeys /etc/ssh/krl.krl
        #HostCertificate /etc/ssh/ssh_host_ed25519_key-cert.pub
        #HostCertificate /etc/ssh/ssh_host_rsa_key-cert.pub

        #Match User packer,user2
        Match User packer
            X11Forwarding yes
            AllowTcpForwarding yes
            X11UseLocalHost yes
            X11DisplayOffset 10
    - append_if_not_found: True

{% if salt['file.file_exists'](varsdict.skeldir_ssh ~ '/publish_krls/sshca-id_rsa.pub') %}
{% set sshca_pubkey = salt['file.read'](varsdict.skeldir_ssh ~ '/publish_krls/sshca-id_rsa.pub') %}
  {% if not salt['file.file_exists'](varsdict.skeldir_ssh ~ '/known_hosts') %}
'{{varsdict.skeldir_ssh}}/known_hosts':
  file.copy:
    - source: {{varsdict.skeldir_ssh}}/known_hosts.sample
  {% endif %}

  {#{% for item in {'rexp': '^@cert-authority 192.168.* '
     , 'linepfx': '@cert-authority 192.168.0.0/16'}
     , {'rexp': '^@cert-authority 172.16.* ', 'linepfx': '@cert-authority 172.16.0.0/12'}
     , {'rexp': '^@cert-authority 10.0.* ', 'linepfx': '@cert-authority 10.0.0.0/8'}
     , {'rexp': '^@cert-authority fd00.* ', 'linepfx': '@cert-authority fd00::/8'} %}#}
  {% for item in {'rexp': '^@cert-authority 192.168.* '
     , 'linepfx': '@cert-authority 192.168.0.0/16'} %}
'Edit {{item.rexp}} to {{item.linepfx}}':
  file.replace:
    - name: {{varsdict.skeldir_ssh}}/known_hosts
    - pattern: '{{item.rexp}}'
    - repl: '{{item.linepfx}} {{sshca_pubkey}}'
    - append_if_not_found: True
  {% endfor %}

Copy & keep permissions|attributes SSH CA pubkey & krl to /etc/ssh/:
  cmd.run:
    #- shell: /bin/sh
    - name: cp -a {{varsdict.skeldir_ssh}}/publish_krls/krl.krl {{varsdict.skeldir_ssh}}/publish_krls/sshca-id_rsa.pub /etc/ssh/
{% endif %}

{#
#Config shellrc keychain w/ shell script:
#  cmd.run:
#    #- shell: /bin/sh
#    - name: sh /root/init/common/misc_config.sh cfg_shell_keychain {{varsdict.skel_shellrc}}
#}

'{{varsdict.skel_shellrc}}':
  {#-{% if grains['shell'].count('csh') %}#}
  {%- if 'csh' in grains['shell'] %}
  file.blockreplace:
    - content: |
        eval `keychain --agents gpg,ssh --eval`
        unsetenv SSH_AGENT_PID
        setenv GPG_TTY `tty`
        gpg-connect-agent updatestartuptty /bye > /dev/null
        setenv SSH_AUTH_SOCK `gpgconf --list-dirs agent-ssh-socket`
    - append_if_not_found: True
  {%- else %}
  file.blockreplace:
    - content: |
        eval `keychain --agents gpg,ssh --eval`
        unset SSH_AGENT_PID
        export GPG_TTY=`tty`
        gpg-connect-agent updatestartuptty /bye > /dev/null
        export SSH_AUTH_SOCK=`gpgconf --list-dirs agent-ssh-socket`
    - append_if_not_found: True
  {%- endif %}

{#
#Config NFS share w/ shell script:
#  cmd.run:
#    #- shell: /bin/sh
#    - name: sh /root/init/common/misc_config.sh cfg_share_nfs_data0 {{varsdict.sharednode}}
#}

Add NFS share /etc/fstab:
  {% if grains['kernel']|lower not in ['linux'] %}
  file.replace:
    - name: /etc/fstab
    - pattern: '^.*:/mnt/Data0.*'
    - repl: '#{{varsdict.sharednode}}:/mnt/Data0 /media/nfs_Data0  nfs  rw,noauto  0  0'
    - append_if_not_found: True
  {% else %}
  file.replace:
    - name: /etc/fstab
    - pattern: '^.*:/mnt/Data0.*'
    - repl: '#{{varsdict.sharednode}}:/mnt/Data0 /media/nfs_Data0  nfs  rw,noauto,users,rsize=8192,wsize=8192,timeo=14,_netdev  0  0'
    - append_if_not_found: True
  {% endif %}

/media/nfs_Data0:
  file.directory

{#
#Config CUPS printer default w/ shell script:
#  cmd.run:
#    #- shell: /bin/sh
#    - name: sh /root/init/common/misc_config.sh cfg_printer_default {{varsdict.sharednode}} {{varsdict.printname}}
#}
{#
cups lpadmin (default):
  cmd.run:
    #- shell: /bin/sh
    - name: |
        ## Configure printer using CUPS web interface
        # w3m http://localhost:631

        #lpadmin -E -U root -p {{varsdict.printname}} -D "{{varsdict.printname}}" -L localhost -v "ipp://{{varsdict.sharednode}}/printers/{{varsdict.printname}}"
        #lpadmin -E -U root -d {{varsdict.printname}}
        lpadmin -E -U root -p {{varsdict.printname}} -v "ipp://{{varsdict.sharednode}}/printers/{{varsdict.printname}}"
        lpadmin -E -U root -d {{varsdict.printname}}
#}

{#
#Config CUPS printer PDF w/ shell script:
#  cmd.run:
#    #- shell: /bin/sh
#    - name: sh /root/init/common/misc_config.sh cfg_printer_pdf {{varsdict.etcdir_cups}} {{varsdict.cupsdir_ppd}}
#}
{#
'{{varsdict.etcdir_cups}}/cups-pdf.conf':
  file.replace:
    - pattern: '^Out .*'
    - repl: 'Out ${HOME}/Documents/PDF'
    - append_if_not_found: True

cups lpadmin (pdf):
  cmd.run:
    #- shell: /bin/sh
    - name: |
        lpadmin -E -U root -p CUPS_PDF -v "cups-pdf:/" -i {{varsdict.cupsdir_ppd}}/CUPS-PDF_opt.ppd
        lpadmin -E -U root -d CUPS_PDF
#}
