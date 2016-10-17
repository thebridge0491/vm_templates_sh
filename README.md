# Vm_templates_sh
<!-- .md to .html: markdown foo.md > foo.html
                   pandoc -s -f markdown_strict -t html5 -o foo.html foo.md -->

Virtual machine templates (KVM/QEMU or VirtualBox hybrid boot: BIOS+UEFI) using auto install methods and/or chroot install scripts

## Download options
source code tarball download:
        
        # [aria2c --check-certificate=false | fetch --no-verify-peer | ftp -S dont | wget --no-check-certificate | curl -kOL]
        FETCHCMD='aria2c --check-certificate=false'
        $FETCHCMD https://bitbucket.org/thebridge0491/vm_templates_sh/get/master.zip
        $FETCHCMD https://github.com/thebridge0491/vm_templates_sh/archive/master.zip

version control repository clone:
        
        # https://[bitbucket.org | github.com]
        git clone https://bitbucket.org/thebridge0491/vm_templates_sh.git

## Usage
if needed, create/update JSON file for iso variables:
		
		cp iso_vars.json.sample iso_vars.json ; $EDITOR iso_vars.json

to build virtual machine from iso:
		
		 PLAIN_PASSWD=abcd0123 ; PACKER_CMD=$HOME/bin/packer
		CRYPTED_PASSWD=$(python -c "import crypt,getpass ; print(crypt.crypt(getpass.getpass(), '\$6\$16CHARACTERSSALT'))")
		$PACKER_CMD build -var plain_passwd=$PLAIN_PASSWD -var crypted_passwd=$CRYPTED_PASSWD \
			[-var-file iso_vars.json] -only=[qemu|virtualbox-iso] template.json

## Author/Copyright
Copyright (c) 2016 by thebridge0491 <thebridge0491-codelab@yahoo.com>


## License
Licensed under the Apache-2.0 License. See LICENSE for details.
