#!/usr/bin/perl -cw
#
# passwd crypted hash: [md5|sha256|sha512|yescrypt] - [$1|$5|$6|$y$j9T]$...
# stty -echo ; openssl passwd -6 -salt 16CHARACTERSSALT -stdin ; stty echo
# stty -echo ; perl -le 'print STDERR "Password:\n" ; $_=<STDIN> ; chomp $_ ; print crypt($_, "\$6\$16CHARACTERSSALT")' ; stty echo
# ruby -e '["io/console","digest/sha2"].each {|i| require i} ; STDERR.puts "Password:" ; puts STDIN.noecho(&:gets).chomp.crypt("$6$16CHARACTERSSALT")'
# python -c 'import crypt,getpass ; print(crypt.crypt(getpass.getpass(), "$6$16CHARACTERSSALT"))'

# You should check the syntax of this file before using it in an auto-install.
# You can do this with 'perl -cw auto_inst.cfg.pl' or by executing this file
# (note the '#!/usr/bin/perl -cw' on the first line).
$o = {
  'X' => { 'disabled' => 1 },
  'authentication' => { 'sha512' => 1, 'shadow' => 1 },
  'autoExitInstall' => '1',
#  'interactiveSteps' => [
#    'doPartitionDisks', 'formatPartitions'
#  ],
  'partitioning' => { 'auto_allocate' => '1', #'clear' => [ '[sv]da' ],
    'clearall' => 0
  },
  'default_packages' => [
    'basesystem', 'kernel-server-latest', 'microcode_ctl', 'locales-en',
    'pciutils', 'sudo', 'dhcpcd', 'man-pages', 'dosfstools', 'lvm2', 'grub',
    'grub2-efi', 'efibootmgr', 'openssh-server', 'nano', 'urpmi', 'dnf',
    'dnf-plugins-core', 'python3-dnf-plugin-versionlock', 'python3-urllib3' #, 'harddrake-ui', 'xdm', 'task-xfce'
  ],
  'enabled_media' => [
    'Core Release (Installer)', 'Nonfree Release (Installer)',
    'Core Release', 'Nonfree Release', 'Core Updates', 'Nonfree Updates'
  ],
  'keyboard' => { 'GRP_TOGGLE' => '', 'KEYBOARD' => 'us' },
  'locale' => {
    'IM' => undef, 'country' => 'US', 'lang' => 'en_US',
    'langs' => { 'en_US' => 1 }, 'utf8' => 1
  },
  'mouse' => {
    'EmulateWheel' => undef, 'MOUSETYPE' => 'ps/2',
    'Protocol' => 'ExplorerPS/2', 'device' => 'input/mice',
    'evdev_mice_all' => [
      { 'HWheelRelativeAxisButtons' => '7 6',
        'device' => '/dev/input/by-id/usb-noserial-event-mouse'
      },
      { 'HWheelRelativeAxisButtons' => '7 6',
        'device' => '/dev/input/by-id/usb-Atmel_Atmel_maXTouch_Digitizer-event-mouse'
      }
    ],
    'name' => 'Any PS/2 & USB mice', 'nbuttons' => 7, 'synaptics' => undef,
    'type' => 'Universal', 'wacom' => []
  },
  'net' => { 'PROFILE' => 'default', 'ifcfg' => {}, 'net_interface' => undef,
    'network' => { 'CRDA_DOMAIN' => 'US', 'HOSTNAME' => 'mageia-boxv0000',
      'NETWORKING' => 'yes'
    },
    'resolv' => { 'DOMAINNAME' => undef, 'DOMAINNAME2' => undef,
      'DOMAINNAME3' => undef, 'dnsServer' => undef, 'dnsServer2' => undef,
      'dnsServer3' => undef
    },
    'type' => 'ethernet',
    'ethernet' => {},
    'wireless' => {},
    'zeroconf' => {}
  },
  'partitions' => [
    { 'hd' => undef, 'pt_type' => 'BIOS_GRUB', 'size' => 2 << 10 # 1MB
    },
    { 'hd' => undef, 'type' => 0xef, 'fs_type' => 'vfat',
      'mntpoint' => '/boot/efi', 'options' => 'umask=0,iocharset=utf8',
      'size' => 512 * 2 << 10 # 512MB
    },
    { 'hd' => undef, 'type' => 0x83, 'fs_type' => 'ext2',
      'mntpoint' => '/boot', 'size' => 1 << 20 # 1GB
    },
    { 'hd' => undef, 'type' => 0x82, 'fs_type' => 'swap',
      'mntpoint' => 'swap', 'options' => 'defaults',
      'size' => 4 * 2 << 20 # 4GB
    },

    # VM lvm partitioning (pvol0: osRoot, osVar, osSnap, osHome)
    { 'hd' => undef, 'pt_type' => 0x8e, 'mntpoint' => 'pvol0',
      'size' => 2 << 20, 'ratio' => 100 # remaining ~24GB
    },
    { 'VG_name' => 'vg0', 'hd' => 'vg0', 'fs_type' => 'ext4',
      'mntpoint' => '/', 'options' => 'noatime,acl',
      'size' => 12 * 2 << 20 # 12GB
    },
    { 'VG_name' => 'vg0', 'hd' => 'vg0', 'fs_type' => 'ext4',
      'mntpoint' => '/var', 'options' => 'noatime,acl',
      'size' => 5 * 2 << 20 # 5GB
    },
    { 'VG_name' => 'vg0', 'hd' => 'vg0', 'fs_type' => 'ext4',
      #'mntpoint' => '/snap',
      'options' => 'noatime,acl',
      'size' => 2100 * 2 << 10 # 2100MB
    },
    { 'VG_name' => 'vg0', 'hd' => 'vg0', 'fs_type' => 'ext4',
      'mntpoint' => '/home', 'options' => 'noatime,acl',
      'size' => 2 << 20, 'ratio' => 100 # remaining
    }

    ## VM std partitioning (osRoot, osVar, osHome)
    #{ 'hd' => undef, 'type' => 0x83, 'fs_type' => 'ext4',
    #  'mntpoint' => '/', 'options' => 'noatime,acl',
    #  'size' => 12 * 2 << 20 # 12GB
    #},
    #{ 'hd' => undef, 'type' => 0x83, 'fs_type' => 'ext4',
    #  'mntpoint' => '/var', 'options' => 'noatime,acl',
    #  'size' => 5 * 2 << 20 # 5GB
    #},
    #{ 'hd' => undef, 'type' => 0x83, 'fs_type' => 'ext4',
    #  'mntpoint' => '/home', 'options' => 'noatime,acl',
    #  'size' => 2 << 20, 'ratio' => 100 # remaining
    #}
  ],
  'security' => 1,
  'security_user' => undef,
  'services' => [
    'lvm2-monitor', 'mandriva-everytime', 'network', 'network-up', 'partmon',
    'resolvconf', 'sshd'
  ],
  'superuser' => {
    'uid' => '0',
    'gid' => '0',
    'realname' => 'root',
    'shell' => '/bin/bash',
    'home' => '/root',
    #'password' => 'packer',
    'pw' => '$6$16CHARACTERSSALT$A4i3yeafzCxgDj5imBx2ZdMWnr9LGzn3KihP9Dz0zTHbxw31jJGEuuJ6OB6Blkkw0VSUkQzSjE9n4iAAnl0RQ1'
  },
  'timezone' => {
    'UTC' => 1,
    'ntp' => undef,
    'timezone' => 'America/New_York'
  },
  'users' => [
    {
      'name' => 'packer',
      'uid' => undef,
      'gid' => undef,
      'groups' => ['wheel'],
      'realname' => 'Packer User',
      'shell' => '/bin/bash',
      'icon' => 'default',
      #'password' => 'packer',
      'pw' => '$6$16CHARACTERSSALT$A4i3yeafzCxgDj5imBx2ZdMWnr9LGzn3KihP9Dz0zTHbxw31jJGEuuJ6OB6Blkkw0VSUkQzSjE9n4iAAnl0RQ1'
    }
  ],
  'postInstall' => '
    #depmod -a ; modprobe dm-mod ; modprobe dm-crypt

    init_hostname=$(cat /etc/hostname)
    sed -i "/^127.0.1.1/ s|127.0.1.1|#127.0.1.1|" /etc/hosts
    echo "127.0.1.1   ${init_hostname}.localdomain  ${init_hostname}" >> /etc/hosts

    #cp -a /usr/share/systemd/tmp.mount /etc/systemd/system/
    #systemctl enable tmp.mount
    echo "tmpfs                           /tmp        tmpfs   defaults,nosuid,nodev,mode=1777   0   0" >> /etc/fstab


    mkdir -m 0700 -p /home/packer/.ssh ; chown -R packer /home/packer
    #echo "#Defaults:packer !requiretty" >> /etc/sudoers.d/99_packernopasswd
    #echo "packer ALL=(ALL:ALL) NOPASSWD: ALL" >> /etc/sudoers.d/99_packernopasswd
    #chmod 0440 /etc/sudoers.d/99_packernopasswd

    #sed -i "/^[^#].*requiretty/ s|^|#|" /etc/sudoers
    echo "#Defaults:%wheel !requiretty" >> /etc/sudoers.d/99_wheelnopasswd
    echo "%wheel ALL=(ALL:ALL) NOPASSWD: ALL" >> /etc/sudoers.d/99_wheelnopasswd


    mkdir -p /boot/efi/EFI/BOOT
    if [ -e /boot/efi/EFI/mageia/grubaa64.efi ] ; then
      cp /boot/efi/EFI/mageia/grubaa64.efi /boot/efi/EFI/BOOT/BOOTAA64.EFI ;
    else
      cp /boot/efi/EFI/mageia/grubx64.efi /boot/efi/EFI/BOOT/BOOTX64.EFI ;
    fi

    echo GRUB_PRELOAD_MODULES="lvm" >> /etc/default/grub
    sed -ie "/^GRUB_CMDLINE_LINUX_DEFAULT/ s|^\(.*\)$|#\1\n\1|" /etc/default/grub

    sed -ie "/^GRUB_CMDLINE_LINUX_DEFAULT/ s|=\"\(.*\)\"|=\"\1 rootdelay=5\"|"  \
      /etc/default/grub
    #grub2-install --target=i386-pc --recheck /dev/[sv]da
    if [ "`dmesg | grep -iE \'kvm|qemu|hypervisor\'`" ] ; then
      sed -ie \'/^GRUB_CMDLINE_LINUX_DEFAULT/ s|="\(.*\)"|="\1 net.ifnames=0 biosdevname=0"|\' /etc/default/grub ;
    fi
    grub2-mkconfig -o /boot/grub2/grub.cfg

    dnf -y clean all
    fstrim -av
    sync
  '
};
