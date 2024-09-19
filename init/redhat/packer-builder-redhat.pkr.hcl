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
  default = "debootstrap"
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
    "file://${var.isos_pardir}/redhat/aarch64/${var.iso_base_aa64}.iso",
    "https://${var.mirror_host_aa64}${var.iso_url_directory_aa64}/${var.iso_base_aa64}.iso"] : [
    "file://${var.isos_pardir}/redhat/${var.iso_base_x64}.iso",
    "https://${var.mirror_host_x64}${var.iso_url_directory_x64}/${var.iso_base_x64}.iso"]
  iso_checksum     = ("aarch64" == var.MACHINE ?
    "file:file://${var.isos_pardir}/redhat/aarch64/CHECKSUM" :
    "file:file://${var.isos_pardir}/redhat/CHECKSUM")

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
    ["-smp", "cpus=2"], ["-m", "size=4096"], ["-boot", "order=cdn,menu=on"],
    ["-name", "{{.Name}}"],
    ["-device", "virtio-net,netdev=user.0,mac=52:54:00:${formatdate("hh:mm:ss", timestamp())}"],
    ["-device", "usb-ehci,id=usb"], ["-usb"], ["-device", "usb-kbd"],
    ["-device", "usb-tablet"], ["-display", "gtk,show-cursor=on"],
    ["-vga", "none"], ["-device", "virtio-gpu-pci"],
    ["-smbios", "type=0,uefi=on"], ["-bios", "${var.qemu_firmware_aa64}"]
    #, ["-virtfs", "local,id=fsdev0,path=/mnt/Data0,mount_tag=9p_Data0,security_model=passthrough"]
    ] : [
    ["-cpu", "SandyBridge"], ["-machine", "q35,accel=kvm:hvf:tcg"],
    ["-smp", "cpus=2"], ["-m", "size=4096"], ["-boot", "order=cdn,menu=on"],
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

  boot_command_aa64_auto = ["<wait>c<wait>linux /images/pxeboot/vmlinuz* ",
    "inst.stage2=hd:LABEL=${var.iso_cdlabel_aa64} ro ${var.boot_cmdln_options} ",
     "inst.ks=http://{{.HTTPIP}}:{{.HTTPPort}}/${var.variant}/${var.vol_mgr}-ks.cfg inst.repo=http://${var.mirror_host_aa64}${var.repo_directory_aa64} ",
     "ip=::::${var.variant}-boxv0000::dhcp inst.selinux=1 inst.enforcing=0 ",
     "inst.text<enter><wait10>",
    "initrd /images/pxeboot/initrd*.img<enter><wait10>boot<enter><wait10>"]

  /*
  boot_command_x64_auto = ["<wait>c<wait>linuxefi /isolinux/vmlinuz* ",
    "inst.stage2=hd:LABEL=${var.iso_cdlabel_x64} ro ${var.boot_cmdln_options} ",
     "inst.ks=http://{{.HTTPIP}}:{{.HTTPPort}}/${var.variant}/${var.vol_mgr}-ks.cfg inst.repo=http://${var.mirror_host_x64}${var.repo_directory_x64} ",
     "ip=::::${var.variant}-boxv0000::dhcp inst.selinux=1 inst.enforcing=0 ",
     "inst.text<enter><wait10>",
     "initrdefi /isolinux/initrd*.img<enter><wait10>boot<enter><wait10>"]
  */

  boot_command_x64_auto  = ["<wait>c<wait>linuxefi /images/pxeboot/vmlinuz* ${var.boot_cmdln_options} ",
    "inst.ks=http://{{.HTTPIP}}:{{.HTTPPort}}/${var.variant}/${var.vol_mgr}-ks.cfg ",
    "inst.repo=http://${var.mirror_host_x64}${var.repo_directory_x64} ",
    "ip=::::${var.variant}-boxv0000::dhcp inst.selinux=1 inst.enforcing=0 ",
    "inst.text<enter><wait10>",
    "initrdefi /images/pxeboot/initrd*.img<enter><wait10>boot<enter><wait10>"]

  boot_command_x64_chroot = ["<down><up><wait><wait><wait>c<wait>",
    "linuxefi /isolinux/vmlinuz* root=live:LABEL=${var.iso_cdlabel_x64} ro ",
    "rd.live.image rhgb text ${var.boot_cmdln_options} textmode=1 text 3 ",
    "systemd.unit=multi-user.target<enter>",
    "initrdefi /isolinux/initrd*.img<enter>boot<enter><wait2m>",
    "<enter>liveuser<enter><wait10>sudo su<enter><wait10>",
    "dnf -y check-update ; setenforce 0 ; sestatus ; ",
    "dnf -y install nmap-ncat lvm2 ${var.foreign_pkgmgr} ; sleep 5 ; ",
    "cd /tmp ; wget 'http://{{.HTTPIP}}:{{.HTTPPort}}/common/disk_setup.sh' 'http://{{.HTTPIP}}:{{.HTTPPort}}/${var.variant}/install.sh' ; ",
    "if [ 'zfs' = '${var.vol_mgr}' ] ; then ",
    ". /etc/os-release ; mount -o remount,size=1500M /run ; df -h ; sleep 5 ; ",
    "dnf -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-$(echo $${VERSION_ID} | cut -d. -f1).noarch.rpm ; ",
    "dnf -y install kernel kernel-devel ; ",
    "dnf -y install http://download.zfsonlinux.org/epel/zfs-release-2-2.el$${VERSION_ID/.*/}.noarch.rpm ; ",
    "rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-zfsonlinux ; ",
    "dnf config-manager --disable zfs ; dnf config-manager --enable zfs-kmod ; ",
    "dnf -y install zfs ; echo REMAKE_INITRD=yes > /etc/dkms/zfs.conf ; ",
    "dkms status ; dnf config-manager --disable zfs-kmod ; ",
    "dnf config-manager --enable zfs ; sleep 5 ; ",
    "fi ; ", "env MKFS_CMD=$${MKFS_CMD:-mkfs.ext4} sh -x /tmp/disk_setup.sh part_format sgdisk ${var.vol_mgr} ; ",
    "sh -x /tmp/disk_setup.sh mount_filesystems ${var.vol_mgr}<enter><wait30s>",
    "env MIRROR=${var.MIRROR} RELEASE=${var.RELEASE} VOL_MGR=${var.vol_mgr} sh -x /tmp/install.sh run_install ${var.variant}-boxv0000 '${var.passwd_crypted}'<enter><wait>"]

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
