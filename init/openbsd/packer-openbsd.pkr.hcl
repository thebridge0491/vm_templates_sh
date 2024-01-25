# usage example: (packer init <dir>[/template.pkr.hcl] ; [PACKER_LOG=1 PACKER_LOG_PATH=/tmp/packer.log] packer build -only=qemu.qemu_x86_64 <dir>[/template.pkr.hcl])

variable "MIRROR" {
  type    = string
  default = ""
}

variable "REL" {
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

variable "iso_base_aa64" {
  type    = string
  default = "arm64/install74"
}

variable "iso_base_x64" {
  type    = string
  default = "amd64/install74"
}

variable "iso_url_directory" {
  type    = string
  default = "/7.4"
}

variable "isos_pardir" {
  type    = string
  default = "/mnt/Data0/distros"
}

variable "mirror_host" {
  type    = string
  default = "cdn.openbsd.org/pub/OpenBSD"
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
  default = "openbsd"
}

variable "vboxguest_ostype" {
  type    = string
  default = "OpenBSD_64"
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
  boot_command       = ["<wait10><wait10><wait10><wait10><wait10><wait10>", "<wait10><wait10><wait10><wait10><wait10><wait10>", "S<enter><wait10>dhclient vio0 ; ifconfig vio0 inet autoconf<enter><wait>", "cd /tmp ; ftp http://{{.HTTPIP}}:{{.HTTPPort}}/${var.variant}/custom.disklabel http://{{.HTTPIP}}:{{.HTTPPort}}/${var.variant}/install.resp http://{{.HTTPIP}}:{{.HTTPPort}}/${var.variant}/autoinstall.sh ; sync ; sleep 3 ; sh -x /tmp/autoinstall.sh<enter>"]
  boot_wait          = "10s"
  disk_detect_zeroes = "unmap"
  disk_discard       = "unmap"
  disk_image         = "true"
  disk_interface     = "virtio"
  disk_size          = "${var.disk_size}"
  headless           = "${var.headless}"
  http_directory     = "init"
  #iso_checksum       = "file:file://${var.isos_pardir}/openbsd/arm64/SHA256"
  iso_checksum       = "none"
  iso_url            = ""
  iso_urls           = ["file://${var.isos_pardir}/openbsd/${var.iso_base_aa64}.img","https://${var.mirror_host}${var.iso_url_directory}/${var.iso_base_aa64}.img"]
  machine_type       = "virt"
  net_bridge         = "${var.qemunet_bridge}"
  output_directory   = "output-vms/${var.variant}-aarch64-${var.vol_mgr}"
  qemu_binary        = "qemu-system-aarch64"
  qemuargs           = [["-cpu", "cortex-a57"], ["-machine", "virt,gic-version=3,acpi=off"], ["-smp", "cpus=2"], ["-m", "size=2048"], ["-boot", "order=cdn,menu=on"], ["-name", "{{.Name}}"], ["-device", "virtio-net,netdev=user.0,mac=52:54:00:${local.mac_last3}"], ["-device", "qemu-xhci,id=usb"], ["-usb"], ["-device", "usb-kbd"], ["-device", "usb-tablet"], ["-vga", "none"], ["-device", "virtio-gpu-pci"], ["-display", "gtk,show-cursor=on"], ["-smbios", "type=0,uefi=on"], ["-bios", "${var.firmware_qemu_aa64}"]]
  shutdown_command   = "/sbin/shutdown -p +3 || /sbin/poweroff"
  ssh_password       = "${var.passwd_plain}"
  ssh_timeout        = "4h45m"
  ssh_username       = "root"
  vm_name            = "${var.variant}-aarch64-${var.vol_mgr}"
}

source "qemu" "qemu_x86_64" {
  boot_command       = ["<wait10><wait10><wait10><wait10><wait10><wait10>", "S<enter><wait10>dhclient vio0 ; ifconfig vio0 inet autoconf<enter><wait>", "cd /tmp ; ftp http://{{.HTTPIP}}:{{.HTTPPort}}/${var.variant}/custom.disklabel http://{{.HTTPIP}}:{{.HTTPPort}}/${var.variant}/install.resp http://{{.HTTPIP}}:{{.HTTPPort}}/${var.variant}/autoinstall.sh ; sync ; sleep 3 ; sh -x /tmp/autoinstall.sh<enter>"]

  #boot_command         = ["<wait10><wait10><wait10><wait10><wait10><wait10>", "S<enter><wait10>", "mount_mfs -s 100m md1 /tmp ; mount_mfs -s 100m md2 /mnt ; mount -t mfs -s 100m md1 /tmp ; mount -t mfs -s 100m md2 /mnt ; dhclient -L /tmp/dhclient.lease.em0 em0 ; dhclient -L /tmp/dhclient.lease.vio0 vio0 ; ifconfig em0 inet autoconf ; ifconfig vio0 inet autoconf ; cd /tmp ; ftp http://{{.HTTPIP}}:{{.HTTPPort}}/${var.variant}/custom.disklabel http://{{.HTTPIP}}:{{.HTTPPort}}/${var.variant}/disklabel_setup.sh http://{{.HTTPIP}}:{{.HTTPPort}}/${var.variant}/install.sh ; (cd /dev ; sh MAKEDEV sd0) ; sh -x /tmp/disklabel_setup.sh part_format ${var.vol_mgr} ; sh -x /tmp/disklabel_setup.sh mount_filesystems<enter><wait10><wait10><wait10>MIRROR=${var.MIRROR} REL=${var.REL} DISTARCHIVE_FETCH=${var.distarchive_fetch} VOL_MGR=${var.vol_mgr} sh -x /tmp/install.sh run_install ${var.variant}-boxv0000 '${var.passwd_plain}'<enter><wait>"]

  boot_wait          = "10s"
  disk_detect_zeroes = "unmap"
  disk_discard       = "unmap"
  disk_image         = "true"
  disk_interface     = "virtio-scsi"
  disk_size          = "${var.disk_size}"
  headless           = "${var.headless}"
  http_directory     = "init"
  #iso_checksum       = "file:file://${var.isos_pardir}/openbsd/amd64/SHA256"
  iso_checksum       = "none"
  iso_url            = ""
  iso_urls           = ["file://${var.isos_pardir}/openbsd/${var.iso_base_x64}.img","https://${var.mirror_host}${var.iso_url_directory}/${var.iso_base_x64}.img"]
  machine_type       = "pc"
  net_bridge         = "${var.qemunet_bridge}"
  output_directory   = "output-vms/${var.variant}-x86_64-${var.vol_mgr}"
  qemuargs           = [["-cpu", "SandyBridge"], ["-smp", "cpus=2"], ["-m", "size=2048"], ["-boot", "order=cdn,menu=on"], ["-name", "{{.Name}}"], ["-device", "virtio-net,netdev=user.0,mac=52:54:00:${local.mac_last3}"], ["-device", "virtio-scsi"], ["-device", "scsi-hd,drive=drive0"], ["-usb"], ["-display", "gtk,show-cursor=on"], ["-vga", "cirrus"], ["-smbios", "type=0,uefi=on"], ["-bios", "${var.firmware_qemu_x64}"]]
  shutdown_command   = "/sbin/shutdown -p +3 || /sbin/poweroff"
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
