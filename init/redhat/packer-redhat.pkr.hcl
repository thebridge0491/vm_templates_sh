# usage example: (packer init <dir>[/template.pkr.hcl] ; [PACKER_LOG=1 PACKER_LOG_PATH=/tmp/packer.log] packer build -only=qemu.qemu_x86_64 <dir>[/template.pkr.hcl])

variable "RELEASE" {
  type    = string
  default = ""
}

variable "author" {
  type    = string
  default = "thebridge0491"
}

variable "boot_cmdln_options" {
  type    = string
  default = " quiet nomodeset video=1024x768 "
}

variable "disk_size" {
  type    = string
  default = "30720M"
}

variable "firmware_qemu_aa64" {
  type    = string
  default = "/usr/share/AAVMF/AAVMF_CODE.fd"
}

variable "firmware_qemu_x64" {
  type    = string
  default = "/usr/share/OVMF/OVMF_CODE.fd"
}

variable "foreign_pkgmgr" {
  type    = string
  default = "debootstrap"
}

variable "headless" {
  type    = bool
  default = false
}

variable "home" {
  type    = string
  default = "${env("HOME")}"
}

variable "init_hostname" {
  type    = string
  default = "redhat-boxv0000"
}

variable "iso_name_aa64" {
  type    = string
  #default = "aarch64/CentOS-Stream-9-latest-aarch64-boot"
  #default = "aarch64/AlmaLinux-9.1-aarch64-boot"
  default = "aarch64/Rocky-9.1-aarch64-boot"
}

variable "iso_name_x64" {
  type    = string
  #default = "CentOS-Stream-9-latest-x86_64-boot"
  #default = "AlmaLinux-9.1-x86_64-boot"
  default = "Rocky-9.1-x86_64-boot"
}

variable "iso_url_directory" {
  type    = string
  #default = "/9-stream/BaseOS/x86_64/iso"
  default = "9/isos"
}

variable "iso_url_mirror" {
  type    = string
  #default = "https://mirror.stream.centos.org"
  #default = "https://repo.almalinux.org/almalinux"
  default = "https://dl.rockylinux.org/pub/rocky"
}

variable "isolive_cdlabel_aa64" {
  type    = string
  #default = "Rocky-9-1-aarch64-dvd"
  default = "Rocky-9-1-XFCE-aarch64"
}

variable "isolive_cdlabel_x64" {
  type    = string
  #default = "AlmaLinux-9.1-x86_64-Live-XFCE"
  default = "Rocky-9-1-XFCE"
}

variable "isolive_name_aa64" {
  type    = string
  default = "live/Rocky-9.1-XFCE-aarch64-20221124.0"
}

variable "isolive_name_x64" {
  type    = string
  #default = "live/AlmaLinux-9.1-x86_64-Live-XFCE"
  default = "live/Rocky-9.1-XFCE-x86_64-20221124.0"
}

variable "isolive_url_directory" {
  type    = string
  default = "9/live"
}

variable "isos_pardir" {
  type    = string
  default = "/mnt/Data0/distros"
}

variable "mkfs_cmd" {
  type    = string
  default = "mkfs.ext4"
}

variable "nvram_qemu_aa64" {
  type    = string
  default = "/usr/share/AAVMF/AAVMF_VARS.fd"
}

variable "nvram_qemu_x64" {
  type    = string
  default = "/usr/share/OVMF/OVMF_VARS.fd"
}

variable "passwd_crypted" {
  type    = string
  default = ""
  sensitive = true
}

variable "passwd_plain" {
  type    = string
  default = "packer"
  sensitive = true
}

variable "qemunet_bridge" {
  type    = string
  default = "br0"
}

variable "repo_directory" {
  type    = string
  #default = "/9-stream/BaseOS/x86_64/os"
  #default = "/9/BaseOS/x86_64/os"
  default = "/9/BaseOS/x86_64/os"
}

variable "repo_directory_aa64" {
  type    = string
  default = "/9/BaseOS/aarch64/os"
}

variable "repo_host" {
  type    = string
  #default = "mirror.stream.centos.org"
  #default = "repo.almalinux.org/almalinux"
  default = "dl.rockylinux.org/pub/rocky"
}

variable "variant" {
  type    = string
  default = "redhat"
}

variable "vboxguest_ostype" {
  type    = string
  default = "Linux_64"
}

variable "virtfs_opts" {
  type    = string
  default = "local,id=fsdev0,path=/mnt/Data0,mount_tag=9p_Data0,security_model=passthrough"
}

variable "vol_mgr" {
  type    = string
  default = "std"
}

locals {
  #build_timestamp = "${legacy_isotime("2006.01")}"
  #datestamp       = "${legacy_isotime("2006.01.02")}"
  build_timestamp  = "${formatdate("YYYY.MM", timestamp())}"
  datestamp        = "${formatdate("YYYY.MM.DD", timestamp())}"
  mac_last3        = "${formatdate("hh:mm:ss", timestamp())}"
}

source "qemu" "qemu_aarch64" {
  boot_command       = ["<wait>c<wait>linux /images/pxeboot/vmlinuz* inst.stage2=hd:LABEL=${var.isolive_cdlabel_aa64} ro ${var.boot_cmdln_options} ", "inst.ks=http://{{.HTTPIP}}:{{.HTTPPort}}/${var.variant}/${var.vol_mgr}-ks.cfg inst.repo=http://${var.repo_host}${var.repo_directory_aa64} ip=::::${var.init_hostname}::dhcp inst.selinux=1 inst.enforcing=0 inst.text<enter><wait10>", "initrd /images/pxeboot/initrd*.img<enter><wait10>boot<enter><wait10>"]
  boot_wait          = "10s"
  disk_detect_zeroes = "unmap"
  disk_discard       = "unmap"
  disk_interface     = "virtio"
  disk_size          = "${var.disk_size}"
  headless           = "${var.headless}"
  http_directory     = "init"
  iso_checksum       = "file:file://${var.isos_pardir}/redhat/aarch64/CHECKSUM"
  iso_url            = ""
  iso_urls           = ["file://${var.isos_pardir}/redhat/aarch64/${var.iso_name_aa64}.iso","${var.iso_url_mirror}/${var.iso_url_directory}/${var.iso_name_aa64}.iso"]
  machine_type       = "virt"
  net_bridge         = "${var.qemunet_bridge}"
  output_directory   = "output-vms/${var.variant}-aarch64-${var.vol_mgr}"
  qemu_binary        = "qemu-system-aarch64"
  qemuargs           = [["-cpu", "cortex-a57"], ["-machine", "virt,gic-version=3,acpi=off"], ["-smp", "cpus=2"], ["-m", "size=2048"], ["-boot", "order=cdn,menu=on"], ["-name", "{{.Name}}"], ["-device", "virtio-net,netdev=user.0,mac=52:54:00:${local.mac_last3}"], ["-device", "qemu-xhci,id=usb"], ["-usb"], ["-device", "usb-kbd"], ["-device", "usb-tablet"], ["-vga", "none"], ["-device", "virtio-gpu-pci"], ["-display", "gtk,show-cursor=on"], ["-smbios", "type=0,uefi=on"], ["-bios", "${var.firmware_qemu_aa64}"], ["-virtfs", "${var.virtfs_opts}"]]
  shutdown_command   = "sudo shutdown -hP +3 || sudo poweroff"
  ssh_password       = "${var.passwd_plain}"
  ssh_timeout        = "4h45m"
  ssh_username       = "packer"
  vm_name            = "${var.variant}-aarch64-${var.vol_mgr}"
}

source "qemu" "qemu_x86_64" {
  #boot_command         = ["<wait>c<wait>linuxefi /images/pxeboot/vmlinuz* ${var.boot_cmdln_options} ", "inst.ks=http://{{.HTTPIP}}:{{.HTTPPort}}/${var.variant}/${var.vol_mgr}-ks.cfg inst.repo=http://${var.repo_host}${var.repo_directory} ip=::::${var.init_hostname}::dhcp inst.selinux=1 inst.enforcing=0 inst.text<enter><wait10>", "initrdefi /images/pxeboot/initrd*.img<enter><wait10>boot<enter><wait10>"]

  #boot_command       = ["<wait>c<wait>linuxefi /isolinux/vmlinuz* inst.stage2=hd:LABEL=${var.isolive_cdlabel_x64} ro ${var.boot_cmdln_options} ", "inst.ks=http://{{.HTTPIP}}:{{.HTTPPort}}/${var.variant}/${var.vol_mgr}-ks.cfg inst.repo=http://${var.repo_host}${var.repo_directory} ip=::::${var.init_hostname}::dhcp inst.selinux=1 inst.enforcing=0 inst.text<enter><wait10>", "initrdefi /isolinux/initrd*.img<enter><wait10>boot<enter><wait10>"]

  boot_command       = ["<down><up><wait><wait><wait>c<wait>linuxefi /isolinux/vmlinuz* root=live:LABEL=${var.isolive_cdlabel_x64} ro rd.live.image rhgb text ${var.boot_cmdln_options} textmode=1 text 3 systemd.unit=multi-user.target<enter>initrdefi /isolinux/initrd*.img<enter>boot<enter>", "<wait10><wait10><wait10><wait10><wait10><wait10>", "<wait10><wait10><wait10><wait10><wait10><wait10>", "<wait10><wait10><wait10><wait10><wait10><wait10>", "<enter>liveuser<enter><wait10>sudo su<enter><wait10>dnf -y check-update ; setenforce 0 ; sestatus ; dnf -y install ${var.foreign_pkgmgr} nmap-ncat lvm2 ; sleep 5 ; ", "cd /tmp ; wget 'http://{{.HTTPIP}}:{{.HTTPPort}}/common/disk_setup.sh' 'http://{{.HTTPIP}}:{{.HTTPPort}}/${var.variant}/install.sh' ; ", "if [ 'zfs' = '${var.vol_mgr}' ] ; then . /etc/os-release ; dnf -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-$(echo $${VERSION_ID} | cut -d. -f1).noarch.rpm ; dnf -y install kernel kernel-devel ; dnf -y install http://download.zfsonlinux.org/epel/zfs-release-2-2.el$${VERSION_ID/.*/}.noarch.rpm ; rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-zfsonlinux ; dnf config-manager --disable zfs ; dnf config-manager --enable zfs-kmod ; dnf -y install zfs ; echo REMAKE_INITRD=yes > /etc/dkms/zfs.conf ; dkms status ; dnf config-manager --disable zfs-kmod ; dnf config-manager --enable zfs ; sleep 5 ; fi ; ", "env MKFS_CMD=${var.mkfs_cmd} sh -x /tmp/disk_setup.sh part_format sgdisk ${var.vol_mgr} ; sh -x /tmp/disk_setup.sh mount_filesystems ${var.vol_mgr}<enter><wait10><wait10><wait10>env RELEASE=${var.RELEASE} VOL_MGR=${var.vol_mgr} sh -x /tmp/install.sh run_install ${var.init_hostname} '${var.passwd_crypted}'<enter><wait>"]

  boot_wait          = "10s"
  disk_detect_zeroes = "unmap"
  disk_discard       = "unmap"
  disk_interface     = "virtio-scsi"
  disk_size          = "${var.disk_size}"
  headless           = "${var.headless}"
  http_directory     = "init"
  iso_checksum       = "file:file://${var.isos_pardir}/redhat/CHECKSUM"
  iso_url            = ""
  iso_urls           = ["file://${var.isos_pardir}/redhat/${var.isolive_name_x64}.iso","${var.iso_url_mirror}/${var.isolive_url_directory}/x86_64/${var.isolive_name_x64}.iso"]
  machine_type       = "q35"
  net_bridge         = "${var.qemunet_bridge}"
  output_directory   = "output-vms/${var.variant}-x86_64-${var.vol_mgr}"
  qemuargs           = [["-cpu", "SandyBridge"], ["-smp", "cpus=4"], ["-m", "size=4096"], ["-boot", "order=cdn,menu=on"], ["-name", "{{.Name}}"], ["-device", "virtio-net,netdev=user.0,mac=52:54:00:${local.mac_last3}"], ["-device", "virtio-scsi"], ["-device", "scsi-hd,drive=drive0"], ["-usb"], ["-vga", "none"], ["-device", "qxl-vga,vgamem_mb=64"], ["-display", "gtk,show-cursor=on"], ["-smbios", "type=0,uefi=on"], ["-bios", "${var.firmware_qemu_x64}"], ["-virtfs", "${var.virtfs_opts}"]]
  shutdown_command   = "sudo shutdown -hP +3 || sudo poweroff"
  ssh_password       = "${var.passwd_plain}"
  ssh_timeout        = "4h45m"
  ssh_username       = "packer"
  vm_name            = "${var.variant}-x86_64-${var.vol_mgr}"
}

build {
  sources = ["source.qemu.qemu_aarch64", "source.qemu.qemu_x86_64"]

  provisioner "shell-local" {
    inline = ["mkdir -p ${var.home}/.ssh/publish_krls ${var.home}/.pki/publish_crls", "cp -a ${var.home}/.ssh/publish_krls init/common/skel/_ssh/", "cp -a ${var.home}/.pki/publish_crls init/common/skel/_pki/", "tar -cf /tmp/scripts_${var.variant}.tar init/common init/${var.variant} -C scripts ${var.variant}"]
  }

  provisioner "shell-local" {
    inline = ["if command -v erb > /dev/null ; then", "erb author=${var.author} guest=${var.variant}-x86_64-${var.vol_mgr} datestamp=${local.build_timestamp} init/common/catalog.json.erb > output-vms/${var.variant}-x86_64-${var.vol_mgr}/${var.variant}-x86_64-${var.vol_mgr}_catalog.json", "elif command -v pystache > /dev/null ; then", "pystache init/common/catalog.json.mustache '{\"author\":\"${var.author}\",\"guest\":\"${var.variant}-x86_64-${var.vol_mgr}\",\"datestamp\":\"${local.build_timestamp}\"}' > output-vms/${var.variant}-x86_64-${var.vol_mgr}/${var.variant}-x86_64-${var.vol_mgr}_catalog.json", "fi"]
    only   = ["qemu.qemu_x86_64"]
  }

  provisioner "shell-local" {
    inline = ["if command -v erb > /dev/null ; then", "erb author=${var.author} guest=${var.variant}-aarch64-${var.vol_mgr} datestamp=${local.build_timestamp} init/common/catalog.json.erb > output-vms/${var.variant}-aarch64-${var.vol_mgr}/${var.variant}-aarch64-${var.vol_mgr}_catalog.json", "elif command -v pystache > /dev/null ; then", "pystache init/common/catalog.json.mustache '{\"author\":\"${var.author}\",\"guest\":\"${var.variant}-aarch64-${var.vol_mgr}\",\"datestamp\":\"${local.build_timestamp}\"}' > output-vms/${var.variant}-aarch64-${var.vol_mgr}/${var.variant}-aarch64-${var.vol_mgr}_catalog.json", "fi"]
    only   = ["qemu.qemu_aarch64"]
  }

  provisioner "file" {
    destination = "/tmp/scripts.tar"
    generated   = true
    source      = "/tmp/scripts_${var.variant}.tar"
  }

  provisioner "shell" {
    environment_vars = ["HOME_DIR=/home/packer"]
    execute_command  = "env {{.Vars}} sudo sh -x '{{.Path}}'"
    inline           = ["tar -xf /tmp/scripts.tar -C /tmp ; mv /tmp/${var.variant} /tmp/scripts", "cp -a /tmp/init /tmp/scripts /root/"]
  }

  provisioner "shell" {
    environment_vars = ["HOME_DIR=/home/packer"]
    execute_command  = "env {{.Vars}} sudo -E sh -eux '{{.Path}}'"
    scripts          = ["init/${var.variant}/vagrantuser.sh"]
  }

  provisioner "shell" {
    environment_vars = ["HOME_DIR=/home/packer"]
    execute_command  = "env {{.Vars}} sudo -E sh -eux '{{.Path}}'"
    except           = ["qemu.qemu_x86_64", "qemu.qemu_aarch64"]
    scripts          = ["init/common/linux/zerofill.sh"]
  }

  post-processor "checksum" {
    checksum_types = ["sha256"]
    only           = ["qemu.qemu_x86_64"]
    output         = "output-vms/${var.variant}-x86_64-${var.vol_mgr}/${var.variant}-x86_64-${var.vol_mgr}.{{.BuilderType}}.{{.ChecksumType}}"
  }
  post-processor "vagrant" {
    keep_input_artifact  = true
    include              = ["init/common/info.json", "init/common/qemu_lxc/vmrun.sh", "init/common/qemu_lxc/vmrun_qemu_x86_64.args", "init/common/qemu_lxc/vmrun_bhyve.args", "${var.firmware_qemu_x64}", "${var.nvram_qemu_x64}"]
    only                 = ["qemu.qemu_x86_64"]
    output               = "output-vms/${var.variant}-x86_64-${var.vol_mgr}/${var.variant}-x86_64-${var.vol_mgr}-${local.build_timestamp}.{{.Provider}}.box"
    vagrantfile_template = "Vagrantfile.template"
  }
  post-processor "shell-local" {
    inline = ["mv output-vms/${var.variant}-x86_64-${var.vol_mgr}/${var.variant}-x86_64-${var.vol_mgr} output-vms/${var.variant}-x86_64-${var.vol_mgr}/${var.variant}-x86_64-${var.vol_mgr}.qcow2", "cp -a init/common/qemu_lxc/vmrun.sh output-vms/${var.variant}-x86_64-${var.vol_mgr}/"]
    only   = ["qemu.qemu_x86_64"]
  }
  post-processor "checksum" {
    checksum_types = ["sha256"]
    only           = ["qemu.qemu_aarch64"]
    output         = "output-vms/${var.variant}-aarch64-${var.vol_mgr}/${var.variant}-aarch64-${var.vol_mgr}.{{.BuilderType}}.{{.ChecksumType}}"
  }
  post-processor "vagrant" {
    keep_input_artifact  = true
    include              = ["init/common/info.json", "init/common/qemu_lxc/vmrun.sh", "init/common/qemu_lxc/vmrun_qemu_aarch64.args", "${var.firmware_qemu_aa64}", "${var.nvram_qemu_aa64}"]
    only                 = ["qemu.qemu_aarch64"]
    output               = "output-vms/${var.variant}-aarch64-${var.vol_mgr}/${var.variant}-aarch64-${var.vol_mgr}-${local.build_timestamp}.{{.Provider}}.box"
    vagrantfile_template = "Vagrantfile.template"
  }
  post-processor "shell-local" {
    inline = ["mv output-vms/${var.variant}-aarch64-${var.vol_mgr}/${var.variant}-aarch64-${var.vol_mgr} output-vms/${var.variant}-aarch64-${var.vol_mgr}/${var.variant}-aarch64-${var.vol_mgr}.qcow2", "cp -a init/common/qemu_lxc/vmrun.sh output-vms/${var.variant}-aarch64-${var.vol_mgr}/"]
    only   = ["qemu.qemu_aarch64"]
  }
}
