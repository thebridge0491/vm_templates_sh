{% from tpldir ~ "/map.jinja" import varsdict with context %}
{% set variant = {'artix': 'archlinux', 'arch': 'archlinux',
     'centos stream': 'redhat'}.get(grains['os_family']|lower,
     grains['os_family'])|lower %}

'Cmdline-tools packages (variant: {{variant}})':
  {#cmd.run:
    #- shell: /bin/sh
    - name: echo {{varsdict.distro_pkgs.pkgs_cmdln_tools}}#}
  test.show_notification:
    - text: {{varsdict.distro_pkgs.pkgs_cmdln_tools}}
  {% if grains['os_family']|lower in ['artix'] %}
  cmd.run:
    - name: pacman -Sy --noconfirm --needed {{varsdict.distro_pkgs.pkgs_cmdln_tools.replace('"', '')}}
  {% elif grains['os_family']|lower in ['pclinuxos'] %}
  cmd.run:
    - name: apt-get -y --fix-broken install {{varsdict.distro_pkgs.pkgs_cmdln_tools.replace('"', '')}}
  {% elif grains['os_family']|lower in ['centos stream', 'mageia'] %}
  cmd.run:
    - name: dnf -y install {{varsdict.distro_pkgs.pkgs_cmdln_tools.replace('"', '')}}
  {% elif grains['os_family']|lower in ['openbsd'] %}
  cmd.run:
    - name: pkg_add -zIU {{varsdict.distro_pkgs.pkgs_cmdln_tools.replace('"', '')}}
  {% else %}
  pkg.installed:
    - pkgs: {{varsdict.distro_pkgs.pkgs_cmdln_tools.replace('"', '').split(' ')}}
  {% endif %}

{# {% set hostname_0000_if = salt['cmd.shell']('hostname | sed -n "s|\(.*box.\)0000|\1|p"') %} #}
{% set hostname_0000_if = grains.host|regex_match('(.*box.)0000') %}
{% if hostname_0000_if %}

{% for item in varsdict.hostname_chgfiles %}
{{item}}:
  file.replace:
    - pattern: '{{hostname_0000_if[0]}}0000'
    - repl: '{{hostname_0000_if[0]}}{{varsdict.hostname_last4}}'
{% endfor %}

Fix hostname regexp box.0000:
  cmd.run:
    - name: hostname '{{hostname_0000_if[0]}}{{varsdict.hostname_last4}}'
{% endif %}

# conditionally(exists if count > 0) include file
{% if salt['cp.list_master'](prefix=tpldir ~ '/config_' ~ variant ~ '.sls')|count %}
include:
  - {{tpldot}}.config_{{variant}}
{% endif %}

Enable service(s):
  service.enabled:
    - names: {{varsdict.services_enabled}}

Disable service(s):
  service.disabled:
    - names: {{varsdict.services_disabled}}

/etc/nsswitch.conf:
  file.replace:
    - pattern: 'files dns'
    - repl: 'files mdns_minimal [NOTFOUND=return] dns'

{% for item in varsdict.firewall_chgfiles %}
{{item}}:
  file.replace:
    - pattern: 'domain'
    - repl: 'domain, mdns'
{% endfor %}

#Check clamav:
#  cmd.run:
#    - shell: /bin/sh
#    - name: |
#        if command -v wget > /dev/null ; then
#          (cd /tmp ; wget --no-check-certificate https://secure.eicar.org/eicar.com.txt)
#        elif command -v curl > /dev/null ; then
#          (cd /tmp ; curl --insecure --location https://secure.eicar.org/eicar.com.txt)
#        elif command -v aria2c > /dev/null ; then
#          (cd /tmp ; aria2c --check-certificate=false -d . https://secure.eicar.org/eicar.com.txt)
#        elif command -v fetch > /dev/null ; then
#          (cd /tmp ; fetch --retry --mirror --no-verify-peer https://secure.eicar.org/eicar.com.txt)
#        elif command -v ftp > /dev/null ; then
#          (cd /tmp ; ftp -S dont https://secure.eicar.org/eicar.com.txt || ftp https://secure.eicar.org/eicar.com.txt)
#        else
#          echo "Cannot download clamav eicar.com.txt" ;
#          exit 1 ;
#        fi
#        freshclam --verbose ; freshclam --list-mirrors
#        clamscan --verbose /tmp/eicar.com.txt
#        clamscan --recursive /tmp ; rm /tmp/eicar.com.txt

Setup skeleton paths:
  file.directory:
    - names: {{varsdict.skel_dirs}}

{% for item in varsdict.skelmaps_srcdest %}
Xfer {{item.srcskel}} to {{item.destskel}}:
  cmd.run:
    - name: cp -R /root/init/common/skel/{{item.srcskel}} {{varsdict.skeldir_par}}/{{item.destskel}}
{% endfor %}

{% for item in {'rexp': '^.*%' ~ varsdict.sudoers_group ~ '.*ALL.*NOPASSWD.*',
     'line': '%' ~ varsdict.sudoers_group ~ ' ALL=(ALL) NOPASSWD: ALL'},
   {'rexp': '^[^#].*requiretty', 'line': '# Defaults requiretty'} %}
'Change {{item.rexp}} to {{item.line}}':
  file.replace:
    - name: {{varsdict.sudoers_file}}
    - pattern: '{{item.rexp}}'
    - repl: '{{item.line}}'
{% endfor %}

{% for item in {'rexp': '^.*PermitRootLogin.*', 'line': 'PermitRootLogin no'},
   {'rexp': '^.*UseDNS.*', 'line': 'UseDNS no'},
   {'rexp': '^.*GSSAPIAuthentication.*', 'line': 'GSSAPIAuthentication no'} %}
'Change {{item.rexp}} to {{item.line}}':
  file.replace:
    - name: /etc/ssh/sshd_config
    - pattern: '{{item.rexp}}'
    - repl: '{{item.line}}'
{% endfor %}

{% if salt['file.file_exists'](varsdict.skeldir_ssh ~ '/publish_krls/sshca-id_rsa.pub') %}
{% set sshca_pubkey = salt['file.read'](varsdict.skeldir_ssh ~ '/publish_krls/sshca-id_rsa.pub') %}

{#{% for item in [{'rexp': '^@cert-authority 192.168.* ',
   'linepfx': '@cert-authority 192.168.0.0/16'},
   {'rexp': '^@cert-authority 172.16.* ',
   'linepfx': '@cert-authority 172.16.0.0/12'},
   {'rexp': '^@cert-authority 10.0.* ',
   'linepfx': '@cert-authority 10.0.0.0/8'},
   {'rexp': '^@cert-authority fd00.* ', 'linepfx': '@cert-authority fd00::/8'}
   ] %}#}
{% for item in [{'rexp': '^@cert-authority 192.168.* ',
   'linepfx': '@cert-authority 192.168.0.0/16'}
   ] %}
'Edit {{item.rexp}} to {{item.linepfx}}':
  file.replace:
    - name: {{varsdict.skeldir_ssh}}/known_hosts
    - pattern: '{{item.rexp}}'
    - repl: '{{item.linepfx}} {{sshca_pubkey}}'
    - append_if_not_found: True
{% endfor %}

Copy SSH CA pubkey & krl to /etc/ssh/:
  cmd.run:
    - name: cp {{varsdict.skeldir_ssh}}/publish_krls/krl.krl {{varsdict.skeldir_ssh}}/publish_krls/sshca-id_rsa.pub /etc/ssh/
{% endif %}

/etc/ssh/sshd_config:
  file.blockreplace:
    - content: |
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

{{varsdict.skel_shellrc}}:
  file.blockreplace:
    - content: |
        {#-{% if grains['shell'].count('csh') %}#}
        {%- if 'csh' in grains['shell'] %}
        eval `keychain --agents gpg,ssh --eval`
        unsetenv SSH_AGENT_PID
        setenv GPG_TTY `tty`
        gpg-connect-agent updatestartuptty /bye > /dev/null
        setenv SSH_AUTH_SOCK `gpgconf --list-dirs agent-ssh-socket`
        {%- else %}
        eval `keychain --agents gpg,ssh --eval`
        unset SSH_AGENT_PID
        export GPG_TTY=`tty`
        gpg-connect-agent updatestartuptty /bye > /dev/null
        export SSH_AUTH_SOCK=`gpgconf --list-dirs agent-ssh-socket`
        {%- endif %}
    - append_if_not_found: True

Add NFS share /etc/fstab:
  file.replace:
  {% if variant in ['freebsd'] %}
    - name: '/etc/fstab'
    - pattern: '^.*:/mnt/Data0.*'
    - repl: '#{{varsdict.sharednode}}:/mnt/Data0 /media/nfs_Data0  nfs  rw,noauto  0  0'
  {% else %}
    - name: '/etc/fstab'
    - pattern: '^.*:/mnt/Data0.*'
    - repl: '#{{varsdict.sharednode}}:/mnt/Data0 /media/nfs_Data0  nfs  rw,noauto,users,rsize=8192,wsize=8192,timeo=14,_netdev  0  0'
  {% endif %}
    - append_if_not_found: True

/media/nfs_Data0:
  file.directory

#{{varsdict.etcdir_cups}}/cups-pdf.conf:
#  file.replace:
#    - pattern: '^Out .*'
#    - repl: 'Out ${HOME}/Documents/PDF'
#    - append_if_not_found: True

cups lpadmin:
  cmd.run:
    - name: |
        lpadmin -E -U root -p CUPS_PDF -v "cups-pdf:/" -i {{varsdict.cupsdir_ppd}}/CUPS-PDF_opt.ppd
        lpadmin -E -U root -d CUPS_PDF

        ## Configure printer using CUPS web interface
        # w3m http://localhost:631

        ##lpadmin -E -U root -p {{varsdict.printname}} -D "{{varsdict.printname}}" -L localhost -v "ipp://{{varsdict.sharednode}}/printers/{{varsdict.printname}}"
        ##lpadmin -E -U root -d {{varsdict.printname}}
        #lpadmin -E -U root -p {{varsdict.printname}} -v "ipp://{{varsdict.sharednode}}/printers/{{varsdict.printname}}"
        #lpadmin -E -U root -d {{varsdict.printname}}

        lpstat -t
