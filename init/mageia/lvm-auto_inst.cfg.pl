#!/usr/bin/perl -cw
#
# passwd crypted hash: [md5|sha256|sha512] - [$1|$5|$6]$...
# perl -e 'use Term::ReadKey ; print "Password:\n" ; ReadMode "noecho" ; $_=<STDIN> ; ReadMode "normal" ; chomp $_ ; print crypt($_, "\$6\$16CHARACTERSSALT") . "\n"'
# ruby -e "['io/console','digest/sha2'].each {|i| require i} ; puts 'Password:' ; puts STDIN.noecho(&:gets).chomp.crypt(\"\$6\$16CHARACTERSSALT\")"
# python -c "import crypt,getpass ; print(crypt.crypt(getpass.getpass(), \"\$6\$16CHARACTERSSALT\"))"

# You should check the syntax of this file before using it in an auto-install.
# You can do this with 'perl -cw auto_inst.cfg.pl' or by executing this file
# (note the '#!/usr/bin/perl -cw' on the first line).
$o = {
    'X' => { 'disabled' => 1 },
    'authentication' => { 'sha512' => 1, 'shadow' => 1 },
    'autoExitInstall' => '1',
#    'interactiveSteps' => [
#        'doPartitionDisks', 'formatPartitions'
#    ],
    'partitioning' => {
        'auto_allocate' => '1',
        #'clear' => [ '[sv]da' ],
        'clearall' => 0
    },
    'default_packages' => [
        'basesystem', 'kernel-desktop-latest', 'microcode_ctl', 'locales-en',
        'sudo', 'dhcp-client', 'man-pages', 'dosfstools', 'lvm2', 'grub',
        'grub2-efi', 'efibootmgr', 'openssh-server', 'nano', 'mandi-ifw',
        'shorewall', 'shorewall-ipv6', 'urpmi', 'dnf', 'dnf-plugins-core',
        'harddrake-ui', 'xdm'
        #, 'task-xfce'
    ],
    'enabled_media' => [
        'Core Release (Installer)', 'Nonfree Release (Installer)',
        'Core Release', 'Nonfree Release',
        'Core Updates', 'Nonfree Updates'
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
            {
                'HWheelRelativeAxisButtons' => '7 6',
                'device' => '/dev/input/by-id/usb-noserial-event-mouse'
            },
            {
                'HWheelRelativeAxisButtons' => '7 6',
                'device' => '/dev/input/by-id/usb-Atmel_Atmel_maXTouch_Digitizer-event-mouse'
            }
        ],
        'name' => 'Any PS/2 & USB mice',
        'nbuttons' => 7,
        'synaptics' => undef,
        'type' => 'Universal',
        'wacom' => []
    },
    'net' => {
        'PROFILE' => 'default',
        'ifcfg' => {},
        'net_interface' => undef,
        'network' => {
            'CRDA_DOMAIN' => 'US',
            'HOSTNAME' => 'mageia-boxv0000',
            'NETWORKING' => 'yes'
        },
        'resolv' => {
            'DOMAINNAME' => undef,
            'DOMAINNAME2' => undef,
            'DOMAINNAME3' => undef,
            'dnsServer' => undef,
            'dnsServer2' => undef,
            'dnsServer3' => undef
        },
        'type' => 'ethernet',
        'ethernet' => {},
        'wireless' => {},
        'zeroconf' => {}
    },
    'partitions' => [
        {
            'hd' => undef,
            'pt_type' => 'BIOS_GRUB',
            'size' => 2 << 10 # 1MB
        },
        {
            'hd' => undef,
            'type' => 0xef,
            'fs_type' => 'vfat',
            'mntpoint' => '/boot/EFI',
            'options' => 'umask=0,iocharset=utf8',
            'size' => 200 * 2 << 10 # 200MB
        },
        {
            'hd' => undef,
            'pt_type' => 0x8e,
            'mntpoint' => 'pvol0',
            'size' => 2 << 20, # ~29GB
            'ratio' => 100 # remaining
        },
        {
			'VG_name' => 'vg0',
            'hd' => 'vg0',
            'fs_type' => 'swap',
            'mntpoint' => 'swap',
            'options' => 'defaults',
            'size' => 4 * 2 << 20 # 4GB
        },
        {
			'VG_name' => 'vg0',
            'hd' => 'vg0',
            'fs_type' => 'ext4',
            'mntpoint' => '/',
            'options' => 'noatime,acl',
            'size' => 11776 * 2 << 10 # 11776MB
        },
        {
			'VG_name' => 'vg0',
            'hd' => 'vg0',
            'fs_type' => 'ext4',
            'mntpoint' => '/var',
            'options' => 'noatime,acl',
            'size' => 6 * 2 << 20 # 6GB
        },
        {
			'VG_name' => 'vg0',
            'hd' => 'vg0',
            'fs_type' => 'ext4',
            'mntpoint' => '/home',
            'options' => 'noatime,acl',
            'size' => 2 << 20,
            'ratio' => 100 # remaining
        }
    ],
    'security' => 1,
    'security_user' => undef,
    'services' => [
        'crond', 'lvm2-monitor', 'mandriva-everytime',
        'network', 'network-up', 'partmon', 'resolvconf',
        'sshd'
    ],
    'superuser' => {
        'uid' => '0',
        'gid' => '0',
        'realname' => 'root',
        'shell' => '/bin/bash',
        'home' => '/root',
        #'password' => 'abcd0123',
        'pw' => '$6$16CHARACTERSSALT$o/XwaDmfuxBWVf1nEaH34MYX8YwFlAMo66n1.L3wvwdalv0IaV2b/ajr7xNcX/RFIPvfBNj.2Qxeh7v4JTjJ91'
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
            #'password' => 'abcd0123',
            'pw' => '$6$16CHARACTERSSALT$o/XwaDmfuxBWVf1nEaH34MYX8YwFlAMo66n1.L3wvwdalv0IaV2b/ajr7xNcX/RFIPvfBNj.2Qxeh7v4JTjJ91'
        }
    ],
    'postInstall' => '
		init_hostname=$(cat /etc/hostname)
		sed -i "/127.0.1.1/d" /etc/hosts
        echo "127.0.1.1    ${init_hostname}.localdomain    ${init_hostname}" >> /etc/hosts

		sed -i "/^%wheel.*(ALL)\s*ALL/ s|%wheel|# %wheel|" /etc/sudoers
		sed -i "/^#.*%wheel.*NOPASSWD.*/ s|^#.*%wheel|%wheel|" /etc/sudoers
		sed -i "s|^[^#].*requiretty|# Defaults requiretty|" /etc/sudoers

		mkdir -p /boot/EFI/EFI/BOOT
		cp /boot/EFI/EFI/mageia/grubx64.efi /boot/EFI/EFI/BOOT/BOOTX64.EFI

        echo GRUB_PRELOAD_MODULES="lvm" >> /etc/default/grub
        sed -i "/GRUB_CMDLINE_LINUX_DEFAULT/ s|=\"\(.*\)\"|=\"\1 rootdelay=5\"|"  \
			/etc/default/grub
        #grub2-install --target=i386-pc --recheck /dev/[sv]da
        grub2-mkconfig -o /boot/grub2/grub.cfg

        service shorewall stop ; service shorewall6 stop
        systemctl disable shorewall ; systemctl disable shorewall6

        dnf -y clean all
        fstrim -av
        sync
    '
};
