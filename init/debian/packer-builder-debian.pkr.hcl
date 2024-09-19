# usage example: (packer init <dir>[/template.pkr.hcl ;] [PACKER_LOG=1 PACKER_LOG_PATH=/tmp/packer.log] packer [validate | build -only=qemu.guest_vm] [-var-file <dir>/template.pkrvars.hcl] <dir>[/template.pkr.hcl])

variable "MACHINE" {
  type    = string
  default = "x86_64"
}

variable "passwd_crypted" {
  type      = string
  default   = ""
  sensitive = true
}

variable "passwd_plain" {
  type      = string
  default   = "packer"
  sensitive = true
}


# Source provider oriented vars
# ----------
# qemu
variable "qemu_binary" {
  type    = string
  default = ""
}

variable "qemudisk_image" {
  type    = bool
  default = false
}

variable "qemudisk_interface_x64" {
  type    = string
  default = "virtio-scsi"
}

variable "qemu_firmware_x64" {
  type    = string
  default = "/usr/share/OVMF/OVMF_CODE.fd"
}

variable "qemu_nvram_x64" {
  type    = string
  default = "/usr/share/OVMF/OVMF_VARS.fd"
}

variable "qemudisk_interface_aa64" {
  type    = string
  default = "virtio"
}

variable "qemu_firmware_aa64" {
  type    = string
  default = "/usr/share/AAVMF/AAVMF_CODE.fd"
}

variable "qemu_nvram_aa64" {
  type    = string
  default = "/usr/share/AAVMF/AAVMF_VARS.fd"
}


# Source common vars
# ----------
variable "MIRROR" {
  type    = string
  default = ""
}

variable "RELEASE" {
  type    = string
  default = ""
}

variable "disk_size" {
  type    = string
  default = "30720"
}

variable "headless" {
  type    = bool
  default = false
}

variable "isos_pardir" {
  type    = string
  default = "/mnt/Data0/distros"
}

variable "foreign_pkgmgr" {
  type    = string
  default = "dnf zypper"
}


# Builder common vars
# ----------
variable "home" {
  type    = string
  default = "${env("HOME")}"
}

variable "build_timestamp" {
  type    = string
  default = ""
}

locals {
  # General local vars
  #build_timestamp = "${legacy_isotime("2006.01")}"
  #datestamp       = "${legacy_isotime("2006.01.02")}"
  build_timestamp  = ("" != var.build_timestamp ? var.build_timestamp :
    "${formatdate("YYYY.MM", timestamp())}")
  datestamp        = "${formatdate("YYYY.MM.DD", timestamp())}"

  # OS variant oriented local vars
  #iso_url         = ""
  iso_urls         = "aarch64" == var.MACHINE ? [
    "file://${var.isos_pardir}/debian/${var.iso_base_aa64}.iso",
    "https://${var.mirror_host_aa64}${var.iso_url_directory_aa64}/${var.iso_base_aa64}.iso"] : [
    "file://${var.isos_pardir}/debian/${var.iso_base_x64}.iso",
    "https://${var.mirror_host_x64}${var.iso_url_directory_x64}/${var.iso_base_x64}.iso"]
  iso_checksum     = ("aarch64" == var.MACHINE ?
    "file:file://${var.isos_pardir}/debian/arm64/SHA256SUMS" :
    "file:file://${var.isos_pardir}/debian/SHA256SUMS.txt")

  # Source provider oriented local vars
  # qemu
  disk_interface   = ("aarch64" == var.MACHINE ? var.qemudisk_interface_aa64 :
    var.qemudisk_interface_x64)
  qemu_firmware    = ("aarch64" == var.MACHINE ? var.qemu_firmware_aa64 :
    var.qemu_firmware_x64)
  qemu_nvram       = ("aarch64" == var.MACHINE ? var.qemu_nvram_aa64 :
    var.qemu_nvram_x64)
  qemuargs         = "aarch64" == var.MACHINE ? [
    ["-cpu", "cortex-a57"], ["-machine", "virt,gic-version=3,acpi=off"],
    ["-smp", "cpus=2"], ["-m", "size=2048"], ["-boot", "order=cdn,menu=on"],
    ["-name", "{{.Name}}"],
    ["-device", "virtio-net,netdev=user.0,mac=52:54:00:${formatdate("hh:mm:ss", timestamp())}"],
    ["-device", "usb-ehci,id=usb"], ["-usb"], ["-device", "usb-kbd"],
    ["-device", "usb-tablet"], ["-display", "gtk,show-cursor=on"],
    ["-vga", "none"], ["-device", "virtio-gpu-pci"],
    ["-smbios", "type=0,uefi=on"], ["-bios", "${var.qemu_firmware_aa64}"]
    #, ["-virtfs", "local,id=fsdev0,path=/mnt/Data0,mount_tag=9p_Data0,security_model=passthrough"]
    ] : [
    ["-cpu", "SandyBridge"], ["-machine", "q35,accel=kvm:hvf:tcg"],
    ["-smp", "cpus=2"], ["-m", "size=2048"], ["-boot", "order=cdn,menu=on"],
    ["-name", "{{.Name}}"],
    ["-device", "virtio-net,netdev=user.0,mac=52:54:00:${formatdate("hh:mm:ss", timestamp())}"],
    ["-device", "virtio-scsi"], ["-device", "scsi-hd,drive=drive0"],
    ["-device", "usb-ehci,id=usb"], ["-usb"], ["-device", "usb-kbd"],
    ["-device", "usb-tablet"], ["-display", "gtk,show-cursor=on"],
    ["-vga", "virtio"],
    #["-vga", "none"], ["-device", "qxl-vga,vgamem_mb=64"],
    ["-smbios", "type=0,uefi=on"], ["-bios", "${var.qemu_firmware_x64}"]
    #, ["-virtfs", "local,id=fsdev0,path=/mnt/Data0,mount_tag=9p_Data0,security_model=passthrough"]
    ]
  qemu_binary      = ("" != var.qemu_binary ? var.qemu_binary :
    ("aarch64" == var.MACHINE ? "qemu-system-aarch64" : "qemu-system-x86_64"))

  # Source common local vars
  vm_base          = "${var.variant}-${var.MACHINE}-${var.vol_mgr}"
  output_directory = "output-vms/${local.vm_base}"

  boot_command_aa64_auto = ["<wait5><wait>c<wait>linux /linux ${var.boot_cmdln_options} ",
    "auto=true preseed/url=http://{{.HTTPIP}}:{{.HTTPPort}}/${var.variant}/${var.vol_mgr}-preseed.cfg ",
    "hostname=${var.variant}-boxv0000 domain= locale=en_US keymap=us ",
    "console-setup/ask_detect=false mirror/http/hostname=${var.repo_host} ",
    "mirror/http/directory=${var.repo_directory_aa64} ",
    "choose-init/select_init=sysvinit<enter>",
    "initrd /initrd.gz<enter>boot<enter>"]

  boot_command_x64_chroot  = ["<down><up><wait>c<wait>linux /live/vmlinuz ",
    "boot=live components username=devuan textmode=1 text 3 ",
    "${var.boot_cmdln_options}<enter>",
    "initrd /live/initrd.img<enter>boot<enter><wait3m><enter>",
    "devuan<enter>devuan<enter>sudo su<enter>ip link ; sleep 3 ; ",
    "dhcpcd eth0 ; dhclient eth0 ; systemctl stop ssh ; systemctl status ssh ; ",
    "invoke-rc.d ssh stop ; invoke-rc.d ssh status<enter>sleep 3 ; ",
    ". /etc/os-release ; mount -o remount,size=1500M /run/live/overlay ; ",
    "df -h ; sleep 5 ; sed -i '/main.*$/ s|main.*$|main contrib non-free|' /etc/apt/sources.list ; ",
    "apt-get --yes update --allow-releaseinfo-change ; ",
    "apt-get --yes install gdisk lvm2 btrfs-progs ${var.foreign_pkgmgr} ; ",
    "if [ 'zfs' = '${var.vol_mgr}' ] ; then ",
    ". /etc/os-release ; sed -i 's|^#deb|deb|g' /etc/apt/sources.list ; ",
    "apt-get --yes update ; apt-get --yes install --no-install-recommends linux-headers-$(uname -r) ; ",
    "apt-get --yes install -t $${VERSION_CODENAME/ */}-backports --no-install-recommends zfs-dkms zfsutils-linux zfs-initramfs ; ",
    "fi ; cd /tmp ; ",
    "wget 'http://{{.HTTPIP}}:{{.HTTPPort}}/common/disk_setup.sh' 'http://{{.HTTPIP}}:{{.HTTPPort}}/${var.variant}/install.sh' ; ",
    "env MKFS_CMD=$${MKFS_CMD:-mkfs.ext4} sh -x /tmp/disk_setup.sh part_format sgdisk ${var.vol_mgr} ; ",
    "sh -x /tmp/disk_setup.sh mount_filesystems ${var.vol_mgr}<enter><wait30s>",
    "env MIRROR=${var.MIRROR} RELEASE=${var.RELEASE} VOL_MGR=${var.vol_mgr} service_mgr=$${service_mgr:-sysvinit} sh -x /tmp/install.sh run_install ${var.variant}-boxv0000 '${var.passwd_crypted}'<enter><wait>"]

  /*
  boot_command_x64_auto = ["<wait5><wait>c<wait>linux /linux ${var.boot_cmdln_options} ",
    "auto=true preseed/url=http://{{.HTTPIP}}:{{.HTTPPort}}/${var.variant}/${var.vol_mgr}-preseed.cfg ",
    "hostname=${var.variant}-boxv0000 domain= locale=en_US keymap=us ",
    "console-setup/ask_detect=false mirror/http/hostname=${var.repo_host} ",
    "mirror/http/directory=${var.repo_directory_x64} ",
    "choose-init/select_init=sysvinit<enter>",
    "initrd /initrd.gz<enter>boot<enter>"]
  */

  boot_command_x64_auto = ["<wait10><down><tab><wait30>/boot/isolinux/linux ${var.boot_cmdln_options} ",
    "auto=true preseed/url=http://{{.HTTPIP}}:{{.HTTPPort}}/${var.variant}/${var.vol_mgr}-preseed.cfg ",
    "hostname=${var.variant}-boxv0000 domain= locale=en_US keymap=us ",
    "console-setup/ask_detect=false mirror/http/hostname=${var.repo_host} ",
    "mirror/http/directory=${var.repo_directory_x64} ",
    "choose-init/select_init=sysvinit initrd=/boot/isolinux/initrd.gz<enter>"]

  boot_command     = ("aarch64" == var.MACHINE ? local.boot_command_aa64_auto :
    local.boot_command_x64_auto)

  # Builder common local vars

}

source "qemu" "guest_vm" {
  # qemu oriented options
  disk_interface     = local.disk_interface
  disk_size          = var.disk_size
  disk_discard       = "unmap"
  disk_detect_zeroes = "unmap"
  headless           = var.headless
  disk_image         = var.qemudisk_image
  machine_type       = "q35"
  net_bridge         = "br0"
  output_directory   = local.output_directory
  qemuargs           = local.qemuargs
  qemu_binary        = local.qemu_binary

  # Common options
  iso_checksum       = local.iso_checksum
  #iso_url           = local.iso_url
  iso_urls           = local.iso_urls
  http_directory     = "init"
  shutdown_command   = "sudo /sbin/shutdown -hP +3 || (sleep 180 ; sudo /sbin/poweroff)"
  shutdown_timeout   = "10m"
  ssh_username       = "packer"
  ssh_password       = var.passwd_plain
  ssh_timeout        = "4h45m"
  boot_wait          = "10s"
  boot_command       = local.boot_command
  vm_name            = "${local.vm_base}.qcow2"
}

build {
  sources = ["source.qemu.guest_vm"]

  provisioner "shell-local" {
    inline = ["mkdir -p ${var.home}/.ssh/publish_krls ${var.home}/.pki/publish_crls",
      "cp -a ${var.home}/.ssh/publish_krls init/common/skel/_ssh/",
      "cp -a ${var.home}/.pki/publish_crls init/common/skel/_pki/",
      "tar -cf /tmp/scripts_${var.variant}.tar init/common init/${var.variant} -C scripts ${var.variant}"]
  }
  provisioner "file" {
    destination = "/tmp/scripts.tar"
    generated   = true
    source      = "/tmp/scripts_${var.variant}.tar"
  }
  provisioner "shell" {
    environment_vars = ["HOME_DIR=/home/packer"]
    #execute_command  = "sudo chmod +x {{.Path}} ; env {{.Vars}} sudo -E sh -eux '{{.Path}}'"
    execute_command  = "sudo chmod +x {{.Path}} ; env {{.Vars}} sudo -E sh -c {{.Path}}"
    inline           = ["tar -xf /tmp/scripts.tar -C /tmp ; mv /tmp/${var.variant} /tmp/scripts", "cp -a /tmp/init /tmp/scripts /root/"]
  }
  provisioner "shell" {
    environment_vars = ["HOME_DIR=/home/packer"]
    #execute_command  = "sudo chmod +x {{.Path}} ; env {{.Vars}} sudo -E sh -eux '{{.Path}}'"
    execute_command  = "sudo chmod +x {{.Path}} ; env {{.Vars}} sudo -E sh -c {{.Path}}"
    scripts          = ["init/${var.variant}/vagrantuser.sh"]
  }
  provisioner "shell" {
    environment_vars = ["HOME_DIR=/home/packer"]
    #execute_command  = "sudo chmod +x {{.Path}} ; env {{.Vars}} sudo -E sh -eux '{{.Path}}'"
    execute_command  = "sudo chmod +x {{.Path}} ; env {{.Vars}} sudo -E sh -c {{.Path}}"
    except           = ["qemu.guest_vm"]
    scripts          = ["init/common/bsd/zerofill.sh"]
  }

  post-processor "checksum" {
    checksum_types = ["sha256"]
    only           = ["qemu.guest_vm"]
    #output         = "${local.output_directory}/${local.vm_base}.{{.BuilderType}}.{{.ChecksumType}}"
    output         = "${local.output_directory}/${local.vm_base}.qcow2.{{.ChecksumType}}"
  }
  post-processor "shell-local" {
    inline = ["if command -v erb > /dev/null ; then",
      "erb author=${var.author} guest=${local.vm_base} datestamp=${local.build_timestamp} init/common/catalog.json.erb > ${local.output_directory}/${local.vm_base}_catalog.json",
      "elif command -v mustache > /dev/null ; then",
      "echo '{\"author\":\"${var.author}\",\"guest\":\"${local.vm_base}\",\"datestamp\":\"${local.build_timestamp}\"}' | mustache - init/common/catalog.json.mustache > ${local.output_directory}/${local.vm_base}_catalog.json",
      "elif command -v chevron > /dev/null ; then",
      "echo '{\"author\":\"${var.author}\",\"guest\":\"${local.vm_base}\",\"datestamp\":\"${local.build_timestamp}\"}' | chevron -d /dev/stdin init/common/catalog.json.mustache > ${local.output_directory}/${local.vm_base}_catalog.json",
      "elif command -v pystache > /dev/null ; then",
      "pystache init/common/catalog.json.mustache '{\"author\":\"${var.author}\",\"guest\":\"${local.vm_base}\",\"datestamp\":\"${local.build_timestamp}\"}' > ${local.output_directory}/${local.vm_base}_catalog.json",
      "fi", "cp -a init/common/qemu_lxc/vmrun.sh ${local.output_directory}/"]
  }
  post-processor "vagrant" {
    keep_input_artifact  = true
    include              = ["init/common/info.json",
      "init/common/qemu_lxc/vmrun.sh",
      "init/common/qemu_lxc/vmrun_qemu_${var.MACHINE}.args",
      "init/common/qemu_lxc/vmrun_bhyve.args", "${local.qemu_firmware}",
      "${local.qemu_nvram}"]
    only                 = ["qemu.guest_vm"]
    output               = "${local.output_directory}/${local.vm_base}-${local.build_timestamp}.{{.Provider}}.box"
    vagrantfile_template = "Vagrantfile.template"
  }
}
