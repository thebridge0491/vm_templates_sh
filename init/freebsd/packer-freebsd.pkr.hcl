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
  default = " "
}

variable "disk_size" {
  type    = string
  default = "30720M"
}

variable "distarchive_fetch" {
  type    = string
  default = "1"
}

variable "firmware_qemu_aa64" {
  type    = string
  default = "/usr/share/AAVMF/AAVMF_CODE.fd"
}

variable "firmware_qemu_x64" {
  type    = string
  default = "/usr/share/OVMF/OVMF_CODE.fd"
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
  default = "freebsd-boxv0000"
}

variable "iso_base_aa64" {
  type    = string
  default = "FreeBSD-13.1-RELEASE-arm64-aarch64"
}

variable "iso_base_x64" {
  type    = string
  default = "FreeBSD-13.1-RELEASE-amd64"
}

variable "iso_url_directory" {
  type    = string
  default = "releases/ISO-IMAGES/13.1"
}

variable "iso_url_mirror" {
  type    = string
  default = "https://download.freebsd.org/ftp"
}

variable "isos_pardir" {
  type    = string
  default = "/mnt/Data0/distros"
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

variable "variant" {
  type    = string
  default = "freebsd"
}

variable "vboxguest_ostype" {
  type    = string
  default = "FreeBSD_64"
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
  boot_command       = ["<esc><wait5>boot -s<wait><enter><wait10><wait10>/bin/sh<enter><wait>", "<wait10><wait10><wait10><wait10><wait10><wait10>", "<wait10><wait10><wait10><wait10><wait10><wait10>", "<wait10><wait10><wait10><wait10><wait10><wait10>", "<wait10><wait10><wait10><wait10><wait10><wait10>", "<wait10><wait10><wait10><wait10><wait10><wait10>", "mdmfs -s 100m md1 /mnt ; mdmfs -s 100m md2 /tmp ; dhclient -l /tmp/dhclient.leases -p /tmp/dhclient.lease.em0 em0 ; dhclient -l /tmp/dhclient.leases -p /tmp/dhclient.lease.vtnet0 vtnet0 ; cd /tmp ; fetch http://{{.HTTPIP}}:{{.HTTPPort}}/common/gpart_setup.sh http://{{.HTTPIP}}:{{.HTTPPort}}/${var.variant}/${var.vol_mgr}-installscript ; export PASSWD_CRYPTED='${var.passwd_crypted}' ; export INIT_HOSTNAME=${var.init_hostname} ; geom -t ; sleep 3 ; bsdinstall script /tmp/${var.vol_mgr}-installscript<enter>"]
  boot_wait          = "7s"
  disk_detect_zeroes = "unmap"
  disk_discard       = "unmap"
  disk_interface     = "virtio"
  disk_size          = "${var.disk_size}"
  headless           = "${var.headless}"
  http_directory     = "init"
  iso_checksum       = "file:file://${var.isos_pardir}/freebsd/CHECKSUM.SHA256-${var.iso_base_aa64}"
  iso_url            = ""
  iso_urls           = ["file://${var.isos_pardir}/freebsd/${var.iso_base_aa64}-disc1.iso","${var.iso_url_mirror}/${var.iso_url_directory}/${var.iso_base_aa64}-disc1.iso"]
  machine_type       = "virt"
  net_bridge         = "${var.qemunet_bridge}"
  output_directory   = "output-vms/${var.variant}-aarch64-${var.vol_mgr}"
  qemu_binary        = "qemu-system-aarch64"
  qemuargs           = [["-cpu", "cortex-a57"], ["-machine", "virt,gic-version=3,acpi=off"], ["-smp", "cpus=2"], ["-m", "size=2048"], ["-boot", "order=cdn,menu=on"], ["-name", "{{.Name}}"], ["-device", "virtio-net,netdev=user.0,mac=52:54:00:${local.mac_last3}"], ["-device", "qemu-xhci,id=usb"], ["-usb"], ["-device", "usb-kbd"], ["-device", "usb-tablet"], ["-vga", "none"], ["-device", "virtio-gpu-pci"], ["-display", "gtk,show-cursor=on"], ["-smbios", "type=0,uefi=on"], ["-bios", "${var.firmware_qemu_aa64}"]]
  shutdown_command   = "shutdown -p +3 || poweroff"
  ssh_password       = "${var.passwd_plain}"
  ssh_timeout        = "4h45m"
  ssh_username       = "root"
  vm_name            = "${var.variant}-aarch64-${var.vol_mgr}"
}

source "qemu" "qemu_x86_64" {
  #boot_command       = ["2<enter><wait10><wait10><enter><wait5>", "mdmfs -s 100m md1 /mnt ; mdmfs -s 100m md2 /tmp ; dhclient -l /tmp/dhclient.leases -p /tmp/dhclient.lease.em0 em0 ; dhclient -l /tmp/dhclient.leases -p /tmp/dhclient.lease.vtnet0 vtnet0 ; cd /tmp ; fetch http://{{.HTTPIP}}:{{.HTTPPort}}/common/gpart_setup.sh http://{{.HTTPIP}}:{{.HTTPPort}}/${var.variant}/${var.vol_mgr}-installscript ; export PASSWD_CRYPTED='${var.passwd_crypted}' ; export INIT_HOSTNAME=${var.init_hostname} ; geom -t ; sleep 3 ; bsdinstall script /tmp/${var.vol_mgr}-installscript<enter>"]

  boot_command       = ["<wait10><wait10><wait10><wait10><wait10><wait10>", "<wait10><wait10><wait10><wait10><wait10><wait10>", "l<wait5>root<enter><wait10>", "mdmfs -s 100m md1 /mnt ; mdmfs -s 100m md2 /tmp ; mkdir -p /tmp/bsdinstall_etc ; resolvconf -u ; sleep 5 ; dhclient -l /tmp/dhclient.leases -p /tmp/dhclient.lease.em0 em0 ; dhclient -l /tmp/dhclient.leases -p /tmp/dhclient.lease.vtnet0 vtnet0 ; cd /tmp ; fetch http://{{.HTTPIP}}:{{.HTTPPort}}/common/gpart_setup.sh http://{{.HTTPIP}}:{{.HTTPPort}}/${var.variant}/install.sh ; geom -t ; sleep 3 ; sh -x /tmp/gpart_setup.sh part_format ${var.vol_mgr} ; sh -x /tmp/gpart_setup.sh mount_filesystems ${var.vol_mgr}<enter><wait10><wait10><wait10>env RELEASE=${var.RELEASE} DISTARCHIVE_FETCH=${var.distarchive_fetch} VOL_MGR=${var.vol_mgr} sh -x /tmp/install.sh run_install ${var.init_hostname} '${var.passwd_crypted}'<enter><wait>"]

  boot_wait          = "7s"
  disk_detect_zeroes = "unmap"
  disk_discard       = "unmap"
  disk_interface     = "virtio-scsi"
  disk_size          = "${var.disk_size}"
  headless           = "${var.headless}"
  http_directory     = "init"
  iso_checksum       = "file:file://${var.isos_pardir}/freebsd/CHECKSUM.SHA256-${var.iso_base_x64}"
  iso_url            = ""
  iso_urls           = ["file://${var.isos_pardir}/freebsd/${var.iso_base_x64}-disc1.iso","${var.iso_url_mirror}/${var.iso_url_directory}/${var.iso_base_x64}-disc1.iso"]
  machine_type       = "q35"
  net_bridge         = "${var.qemunet_bridge}"
  output_directory   = "output-vms/${var.variant}-x86_64-${var.vol_mgr}"
  qemuargs           = [["-cpu", "SandyBridge"], ["-smp", "cpus=2"], ["-m", "size=2048"], ["-boot", "order=cdn,menu=on"], ["-name", "{{.Name}}"], ["-device", "virtio-net,netdev=user.0,mac=52:54:00:${local.mac_last3}"], ["-device", "virtio-scsi"], ["-device", "scsi-hd,drive=drive0"], ["-usb"], ["-vga", "none"], ["-device", "qxl-vga,vgamem_mb=64"], ["-display", "gtk,show-cursor=on"], ["-smbios", "type=0,uefi=on"], ["-bios", "${var.firmware_qemu_x64}"]]
  shutdown_command   = "shutdown -p +3 || poweroff"
  ssh_password       = "${var.passwd_plain}"
  ssh_timeout        = "4h45m"
  ssh_username       = "root"
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
    execute_command  = "chmod +x {{.Path}} ; env {{.Vars}} sh -c {{.Path}}"
    inline           = ["tar -xf /tmp/scripts.tar -C /tmp ; mv /tmp/${var.variant} /tmp/scripts", "cp -a /tmp/init /tmp/scripts /root/"]
  }

  provisioner "shell" {
    environment_vars = ["HOME_DIR=/home/packer"]
    execute_command  = "chmod +x {{.Path}} ; env {{.Vars}} sh -c {{.Path}}"
    scripts          = ["init/${var.variant}/vagrantuser.sh"]
  }

  provisioner "shell" {
    environment_vars = ["HOME_DIR=/home/packer"]
    execute_command  = "chmod +x {{.Path}} ; env {{.Vars}} sh -c {{.Path}}"
    except           = ["qemu.qemu_x86_64", "qemu.qemu_aarch64"]
    scripts          = ["init/common/bsd/zerofill.sh"]
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
