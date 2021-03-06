Vm_templates
===========================================
.. .rst to .html: rst2html5 foo.rst > foo.html
..                pandoc -s -f rst -t html5 -o foo.html foo.rst

Virtual machine templates (KVM/QEMU hybrid boot: BIOS+UEFI) using auto install methods and/or chroot install scripts.

Installation
------------
source code tarball download:

        # [aria2c --check-certificate=false | wget --no-check-certificate | curl -kOL]

        FETCHCMD='aria2c --check-certificate=false'

        $FETCHCMD https://bitbucket.org/thebridge0491/vm_templates_sh/[get | archive]/master.zip

version control repository clone:

        git clone https://bitbucket.org/thebridge0491/vm_templates_sh.git

Usage
-----
to build virtual machine using auto install methods or chroot scripts:

        # NOTE, relevant comments -- transfer file(s) ; run manual commands

        [VOL_MGR=zfs] sh vminstall_auto.sh [<distro> [<guest>]]

        sh vminstall_chroot.sh [<distro> [<guest>]]

build examples:

        [VOL_MGR=zfs] sh vminstall_auto.sh [freebsd [freebsd-Release-zfs]]

        sh vminstall_chroot.sh [freebsd [freebsd-Release-zfs]]

[optional] Vagrant option - (in running VM) add vagrant user:

        sudo sh /root/init/<variant>/vagrantuser.sh

[optional] Vagrant option - (with VM shutdown) make box:

        cd build/<guest> ; sh vmrun.sh box_vagrant <guest>

to transfer scripts and execute shell provisioning on running virtual machine:

        tar -c init/common init/<variant> -C scripts <variant> | \

          ssh <user>@<ipaddr> "cat - > /tmp/scripts.tar"

        ssh <user>@<ipaddr> <<-EOF

        tar -xf /tmp/scripts.tar -C /tmp ; mv /tmp/<variant> /tmp/scripts

        sudo cp -r /tmp/init /tmp/scripts /root/

        sudo sh /root/scripts/<script>.sh

        EOF

provision example:

        tar -c init/common init/freebsd -C scripts freebsd | \

          ssh packer@10.0.2.15 "cat - > /tmp/scripts.tar"

        ssh packer@10.0.2.15 <<-EOF

        tar -xf /tmp/scripts.tar -C /tmp ; mv /tmp/freebsd /tmp/scripts

        sudo cp -r /tmp/init /tmp/scripts /root/

        sudo sh /root/scripts/upgradepkgs.sh

        EOF

Author/Copyright
----------------
Copyright (c) 2020 by thebridge0491 <thebridge0491-codelab@yahoo.com>

License
-------
Licensed under the Apache-2.0 License. See LICENSE for details.
