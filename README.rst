Vm_templates
===========================================
.. .rst to .html: rst2html5 foo.rst > foo.html
..                pandoc -s -f rst -t html5 -o foo.html foo.rst

Virtual machine templates (QEMU x86_64[, aarch64]) using auto install methods and/or chroot install scripts.

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

        [MACHINE=x86_64 VOL_MGR=std] sh vminstall_auto.sh [<oshost_func> [<guest>]]

        [PROVIDER=libvirt MACHINE=x86_64 variant=<oshost>] sh vminstall_chroot.sh [<oshost_func> [<guest>]]

build examples:

        [VOL_MGR=std] sh vminstall_auto.sh [freebsd_guestvm [freebsd-x86_64-std]]

        [PROVIDER=libvirt variant=freebsd] sh vminstall_chroot.sh [freebsd_guestvm [freebsd-x86_64-std]]

[optional] Vagrant option - (in running VM) add vagrant user:

        sudo sh /root/init/<variant>/vagrantuser.sh

[optional] Vagrant option - (with VM shutdown) make box:

        cd build/<guest> ; [PROVIDER=libvirt] sh vmrun.sh box_vagrant <guest>

to create updated scripts tarball:

        cp -a ${HOME}/.ssh/publish_krls init/common/skel/_ssh/

        cp -a ${HOME}/.pki/publish_crls init/common/skel/_pki/

        tar -cf /tmp/scripts_<variant>.tar init/{common,<variant>} -C scripts <variant>

(shell) transfer /tmp/scripts.tar files to /root/:

        sudo rm -r /tmp/{init,scripts} /root/{init,scripts}

        tar -xf /tmp/scripts.tar -C /tmp ; mv /tmp/<variant> /tmp/scripts

        chown -R $(id -un):$(id -gn) /tmp/{init,scripts}

        sudo cp -fa /tmp/{init,scripts} /root/

(vagrant) transfer /tmp/scripts.tar files to /root/:

        vagrant provision --provision-with xferscripts

(salt) transfer /tmp/scripts.tar files to /root/:

        salt-ssh --sudo --user=packer [--list 'guest#01,' | --roster=scan '10.0.2.10'] \

          state.[test | apply] xferscripts

(ansible) transfer /tmp/scripts.tar files to /root/:

        ansible-playbook -bu packer [--limit 'guest#01,' | --inventory '10.0.2.10,'] \

          etc/ansible/playbook.yml [--check] -t xferscripts

(shell) provisioning example:

        sudo sh /root/scripts/upgradepkgs.sh

(vagrant) provisioning example:

        RUNSCRIPT_ARGS="upgradepkgs.sh" vagrant provision --provision-with runscript

(salt) provisioning example:

        salt-ssh --sudo --user=packer -L 'guest#01,' state.apply upgradepkgs \

          [pillar='{"state1": {"autoconfirm": "YES"}}']

(ansible) provisioning example:

        ansible-playbook -bu packer -l 'guest#01,' etc/ansible/playbook.yml \

          -t upgradepkgs [--extra-vars 'autoconfirm=YES']

Author/Copyright
----------------
Copyright (c) 2020 by thebridge0491 <thebridge0491-codelab@yahoo.com>

License
-------
Licensed under the Apache-2.0 License. See LICENSE for details.
