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
        TODO - fix usage info

Author/Copyright
----------------
Copyright (c) 2016 by thebridge0491 <thebridge0491-codelab@yahoo.com>


License
-------
Licensed under the Apache-2.0 License. See LICENSE for details.
