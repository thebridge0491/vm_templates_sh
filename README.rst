Vm_templates_sh
===========================================
.. .rst to .html: rst2html5 foo.rst > foo.html
..                pandoc -s -f rst -t html5 -o foo.html foo.rst

Virtual machine templates (KVM/QEMU or VirtualBox hybrid boot: BIOS+UEFI) using auto install methods and/or chroot install scripts

Download options
----------------
source code tarball download:
        
        # [aria2c --check-certificate=false | fetch --no-verify-peer | ftp -S dont | wget --no-check-certificate | curl -kOL]
        
        FETCHCMD='aria2c --check-certificate=false'

        $FETCHCMD https://bitbucket.org/thebridge0491/vm_templates_sh/get/master.zip
        
        $FETCHCMD https://github.com/thebridge0491/vm_templates_sh/archive/master.zip

version control repository clone:
        
        # https://[bitbucket.org | github.com]
        
        git clone https://bitbucket.org/thebridge0491/vm_templates_sh.git

Usage
-----
if needed, create/update JSON file for iso variables:
		
		cp iso_vars.json.sample iso_vars.json ; $EDITOR iso_vars.json

to build virtual machine from iso:
		
		 PLAIN_PASSWD=abcd0123 ; PACKER_CMD=$HOME/bin/packer
		
		CRYPTED_PASSWD=$(python -c "import crypt,getpass ; print(crypt.crypt(getpass.getpass(), '\$6\$16CHARACTERSSALT'))")
		
		$PACKER_CMD build -var plain_passwd=abcd0123 -var crypted_passwd=$CRYPTED_PASSWD \
			[-var-file iso_vars.json] -only=[qemu|virtualbox-iso] template.json

to provision running and SSH-accessible virtual machine:
		
		$PACKER_CMD build -only=<build_name> -var distro_name=<distro_name> -var vm_spec=<ssh_host> \
			-var desktop= -var plain_passwd=<pwd> provision.json
		
		# OR using provision_vm.sh script
		
		env CHOICE_DESKTOP= sh provision_vm.sh <ssh_host> <pwd> <build_name> <distro_name>
		
		# ----- examples -----
		
		ex: $PACKER_CMD build -only=update-vm -var distro_name=freebsd -var vm_spec=192.168.0.2 \
			-var desktop= -var plain_passwd=$PLAIN_PASSWD provision-bsd.json
		
		ex: env CHOICE_DESKTOP= sh provision_vm.sh 192.168.0.2 $PLAIN_PASSWD update-vm freebsd

to provision VirtualBox OVF/OVA virtual machine export:
		
		$PACKER_CMD build -only=<build_name> -var distro_name=<distro_name> -var vm_spec=<source_path> \
			-var desktop= -var plain_passwd=<pwd> provision.json
		
		# OR using provision_vm.sh script
		
		env CHOICE_DESKTOP= sh provision_vm.sh <source_path> <pwd> <build_name> <distro_name>
		
		# ----- examples -----
		
		ex: $PACKER_CMD build -only=update-ovf -var distro_name=freebsd -var vm_spec=freebsd-Release \
			-var desktop= -var plain_passwd=$PLAIN_PASSWD provision-bsd.json
		
		ex: env CHOICE_DESKTOP= sh provision_vm.sh freebsd-Release $PLAIN_PASSWD update-ovf freebsd

Author/Copyright
----------------
Copyright (c) 2016 by thebridge0491 <thebridge0491-codelab@yahoo.com>


License
-------
Licensed under the Apache-2.0 License. See LICENSE for details.
