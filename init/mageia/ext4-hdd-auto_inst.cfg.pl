#!/usr/bin/perl -cw
# 
# passwd crypted hash: [md5|sha256|sha512] - [$1|$5|$6]$...
# python -c "import crypt,getpass ; print(crypt.crypt(getpass.getpass(), '\$6\$16CHARACTERSSALT'))"
# perl -e "print crypt('password', '\$6\$16CHARACTERSSALT') . \"\n\""

# You should check the syntax of this file before using it in an auto-install.
# You can do this with 'perl -cw auto_inst.cfg.pl' or by executing this file
# (note the '#!/usr/bin/perl -cw' on the first line).
$o = {
    'X' => { 'disabled' => 1 },
    'authentication' => { 'sha512' => 1, 'shadow' => 1 },
    'autoExitInstall' => '1',
    'interactiveSteps' => [
        'doPartitionDisks', 'formatPartitions'
    ],
    'partitioning' => {
        'auto_allocate' => '1',
        #'clear' => [ 'sda' ],
        'clearall' => 0
    },
    'default_packages' => [
        'basesystem', 'kernel-desktop-latest', 'microcode_ctl', 'locales-en',
        'sudo', 'dhcp-client', 'man-pages', 'dosfstools', 'lvm2', 'grub',
        'grub2-efi', 'efibootmgr', 'openssh-server', 'nano', 'mandi-ifw',
        'shorewall', 'shorewall-ipv6', 'urpmi', 'dnf', 'dnf-plugins-core', 
        'harddrake-ui', 'xdm', , 'task-x11', 'lightdm', 'task-lxde',
        'task-printing'
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
            'HOSTNAME' => 'mageia-boxp0000',
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
            'size' => 84 * 2 << 20 # 84GB
            #'ratio' => 100 # remaining
        },
        {
            'hd' => undef,
            'pt_type' => 0x8e,
            'mntpoint' => 'pvol1',
            'size' => 2 << 20 # 80GB
        },
        {
            'hd' => undef,
            'pt_type' => 0xa5,
            'mntpoint' => 'fsSwap',
            'size' => 4 * 2 << 20, # 4GB
        },
        {
            'hd' => undef,
            'pt_type' => 0xa5,
            'mntpoint' => 'zvol0',
            'size' => 80 * 2 << 20, # 80GB
        },
        {
            'hd' => undef,
            'pt_type' => 0x07,
            'mntpoint' => 'data0',
            'size' => 120 * 2 << 20, # 120GB
        },
        {
            'hd' => undef,
            'pt_type' => 0x07,
            'mntpoint' => 'data1',
            'size' => 2 << 20, # ~80GB
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
            'size' => 16 * 2 << 20 # 16GB
        },
        {
			'VG_name' => 'vg0',
            'hd' => 'vg0',
            'fs_type' => 'ext4',
            'mntpoint' => '/var',
            'options' => 'noatime,acl',
            'size' => 8 * 2 << 20 # 8GB
        },
        {
			'VG_name' => 'vg0',
            'hd' => 'vg0',
            'fs_type' => 'ext4',
            'mntpoint' => '/home',
            'options' => 'noatime,acl',
            'size' => 32 * 2 << 20 # 32 GB
        },
        {
			'VG_name' => 'vg0',
            'hd' => 'vg0',
            'fs_type' => 'ext4',
            #'mntpoint' => '/home', # free
            'options' => 'noatime,acl',
            'size' => 2 << 20, # ~24 GB
            'ratio' => 100 # remaining
        },
        {
			'VG_name' => 'vg1',
            'hd' => 'vg1',
            'fs_type' => 'ext4',
            #'mntpoint' => '/',
            'options' => 'noatime,acl',
            'size' => 16 * 2 << 20 # 16GB
        },
        {
			'VG_name' => 'vg1',
            'hd' => 'vg1',
            'fs_type' => 'ext4',
            #'mntpoint' => '/var',
            'options' => 'noatime,acl',
            'size' => 8 * 2 << 20 # 8GB
        },
        {
			'VG_name' => 'vg1',
            'hd' => 'vg1',
            'fs_type' => 'ext4',
            #'mntpoint' => '/home',
            'options' => 'noatime,acl',
            'size' => 32 * 2 << 20 # 32 GB
        },
        {
			'VG_name' => 'vg1',
            'hd' => 'vg1',
            'fs_type' => 'ext4',
            #'mntpoint' => '/home', # free
            'options' => 'noatime,acl',
            'size' => 2 << 20, # ~24 GB
            'ratio' => 100 # remaining
        }
    ],
    'security' => 1,
    'security_user' => undef,
    'services' => [
        'crond', 'lvm2-monitor', 'mandriva-everytime',
        'network', 'network-up', 'partmon', 'resolvconf'
        #,'sshd'
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
        echo -e "127.0.1.1\t${init_hostname}.localdomain\t${init_hostname}" >> /etc/hosts
		
		sed -i "/^%wheel.*(ALL)\s*ALL/ s|%wheel|# %wheel|" /etc/sudoers
		sed -i "/^#.*%wheel.*NOPASSWD.*/ s|^#.*%wheel|%wheel|" /etc/sudoers
		sed -i "s|^[^#].*requiretty|# Defaults requiretty|" /etc/sudoers
		
		mkdir -p /boot/EFI/EFI/BOOT
		cp /boot/EFI/EFI/mageia/grubx64.efi /boot/EFI/EFI/BOOT/BOOTX64.EFI
		
        echo GRUB_PRELOAD_MODULES="lvm" >> /etc/default/grub
        sed -i "/GRUB_CMDLINE_LINUX_DEFAULT/ s|=\"\(.*\)\"|=\"\1 rootdelay=5\"|"  \
			/etc/default/grub
        #grub2-install --target=i386-pc --recheck /dev/sda
        grub2-mkconfig -o /boot/grub2/grub.cfg
		
		if [ ! "0" = "1" ] ; then
		  DIR_MODE=0750 useradd -m -G wheel -s /bin/bash -c "Vagrant User" vagrant ;
		  echo -n "vagrant:vagrant" | chpasswd ;
		  chown -R vagrant:$(id -gn vagrant) /home/vagrant ;

		  #sh -c "cat > /etc/sudoers.d/99_vagrant" << EOF ;
#Defaults:vagrant !requiretty
#$(id -un vagrant) ALL=(ALL) NOPASSWD: ALL
#
#EOF
		  #chmod 0440 /etc/sudoers.d/99_vagrant ;
		fi
        
        service shorewall stop ; service shorewall6 stop
        systemctl disable shorewall ; systemctl disable shorewall6
    '
};
