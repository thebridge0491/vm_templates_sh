# usage: (export mypass=$(python -c 'import getpass ; print(getpass.getpass())') ; packer init <dir>[/template.pkr.hcl] ; packer build -var passwd_plain=${mypass} -var passwd_crypted=$(python -c 'import os,crypt ; print(crypt.crypt(os.getenv("mypass"), "$6$16CHARACTERSSALT"))') -only=[qemu.qemu_x86_64|qemu.qemu_aarch64|virtualbox-iso.virtualbox_x86_64] <dir>[/template.pkr.hcl])

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
  default = "30720"
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
  default = "openbsd-boxv0000"
}

variable "iso_name_aa64" {
  type    = string
  default = "arm64/install72"
}

variable "iso_name_x64" {
  type    = string
  default = "amd64/install72"
}

variable "iso_url_directory" {
  type    = string
  default = "7.2"
}

variable "iso_url_mirror" {
  type    = string
  default = "https://cdn.openbsd.org/pub/OpenBSD"
}

variable "isos_pardir" {
  type    = string
  default = "/mnt/Data0/distros"
}

variable "passwd_crypted" {
  type    = string
  default = "$6$16CHARACTERSSALT$o/XwaDmfuxBWVf1nEaH34MYX8YwFlAMo66n1.L3wvwdalv0IaV2b/ajr7xNcX/RFIPvfBNj.2Qxeh7v4JTjJ91"
  sensitive = true
}

variable "passwd_plain" {
  type    = string
  default = "abcd0123"
  sensitive = true
}

variable "variant" {
  type    = string
  default = "openbsd"
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
}

source "qemu" "qemu_aarch64" {
  boot_command       = ["<wait10><wait10><wait10><wait10><wait10><wait10>", "<wait10><wait10><wait10><wait10><wait10><wait10>", "S<enter><wait10>dhclient vio0<enter><wait>", "ftp -o /tmp/custom.disklabel http://{{ .HTTPIP }}:{{ .HTTPPort }}/${var.variant}/custom.disklabel ; ftp -o /tmp/install.resp http://{{ .HTTPIP }}:{{ .HTTPPort }}/${var.variant}/install.resp ; ftp -o /tmp/autoinstall.sh http://{{ .HTTPIP }}:{{ .HTTPPort }}/${var.variant}/autoinstall.sh ; sync ; sleep 3 ; sh -x /tmp/autoinstall.sh<enter>"]
  boot_wait          = "10s"
  disk_detect_zeroes = "unmap"
  disk_discard       = "unmap"
  disk_image         = "true"
  disk_interface     = "virtio"
  disk_size          = "${var.disk_size}"
  headless           = "${var.headless}"
  http_directory     = "init"
  iso_checksum       = "file:file://${var.isos_pardir}/openbsd/arm64/SHA256"
  iso_url            = ""
  iso_urls           = ["file://${var.isos_pardir}/openbsd/${var.iso_name_aa64}.img","${var.iso_url_mirror}/${var.iso_url_directory}/${var.iso_name_aa64}.img"]
  machine_type       = "virt"
  output_directory   = "output-vms/${var.variant}-aarch64-${var.vol_mgr}"
  qemu_binary        = "qemu-system-aarch64"
  qemuargs           = [["-cpu", "cortex-a57"], ["-machine", "virt,gic-version=3,acpi=off"], ["-smp", "cpus=2"], ["-m", "size=2048"], ["-boot", "order=cdn,menu=on"], ["-name", "{{ .Name }}"], ["-device", "virtio-net,netdev=user.0"], ["-device", "qemu-xhci,id=usb"], ["-usb"], ["-device", "usb-kbd"], ["-device", "usb-tablet"], ["-vga", "none"], ["-device", "virtio-gpu-pci"], ["-display", "gtk,show-cursor=on"], ["-smbios", "type=0,uefi=on"], ["-bios", "${var.firmware_qemu_aa64}"]]
  shutdown_command   = "shutdown -p +3 || poweroff"
  ssh_password       = "${var.passwd_plain}"
  ssh_timeout        = "4h45m"
  ssh_username       = "root"
  vm_name            = "${var.variant}-aarch64-${var.vol_mgr}"
}

source "qemu" "qemu_x86_64" {
  boot_command       = ["<wait10><wait10><wait10><wait10><wait10><wait10>", "S<enter><wait10>dhclient vio0<enter><wait>", "ftp -o /tmp/custom.disklabel http://{{ .HTTPIP }}:{{ .HTTPPort }}/${var.variant}/custom.disklabel ; ftp -o /tmp/install.resp http://{{ .HTTPIP }}:{{ .HTTPPort }}/${var.variant}/install.resp ; ftp -o /tmp/autoinstall.sh http://{{ .HTTPIP }}:{{ .HTTPPort }}/${var.variant}/autoinstall.sh ; sync ; sleep 3 ; sh -x /tmp/autoinstall.sh<enter>"]
  boot_wait          = "10s"
  disk_detect_zeroes = "unmap"
  disk_discard       = "unmap"
  disk_image         = "true"
  disk_interface     = "virtio-scsi"
  disk_size          = "${var.disk_size}"
  headless           = "${var.headless}"
  http_directory     = "init"
  iso_checksum       = "file:file://${var.isos_pardir}/openbsd/amd64/SHA256"
  iso_url            = ""
  iso_urls           = ["file://${var.isos_pardir}/openbsd/${var.iso_name_x64}.img","${var.iso_url_mirror}/${var.iso_url_directory}/${var.iso_name_x64}.img"]
  machine_type       = "pc"
  output_directory   = "output-vms/${var.variant}-x86_64-${var.vol_mgr}"
  qemuargs           = [["-smp", "cpus=2"], ["-m", "size=2048"], ["-boot", "order=cdn,menu=on"], ["-name", "{{ .Name }}"], ["-device", "virtio-net,netdev=user.0"], ["-device", "virtio-scsi"], ["-device", "scsi-hd,drive=drive0"], ["-usb"], ["-display", "gtk,show-cursor=on"], ["-vga", "cirrus"], ["-smbios", "type=0,uefi=on"], ["-bios", "${var.firmware_qemu_x64}"]]
  shutdown_command   = "shutdown -p +3 || poweroff"
  ssh_password       = "${var.passwd_plain}"
  ssh_timeout        = "2h45m"
  ssh_username       = "root"
  vm_name            = "${var.variant}-x86_64-${var.vol_mgr}"
}

source "virtualbox-iso" "virtualbox_x86_64" {
  boot_command         = ["<wait10><wait10><wait10><wait10><wait10><wait10>", "S<enter><wait10>", "mount_mfs -s 100m md1 /tmp ; mount_mfs -s 100m md2 /mnt ; mount -t mfs -s 100m md1 /tmp ; mount -t mfs -s 100m md2 /mnt ; dhclient -L /tmp/dhclient.lease.em0 em0 ; dhclient -L /tmp/dhclient.lease.vio0 vio0 ; cd /tmp ; ftp -o /tmp/custom.disklabel http://{{ .HTTPIP }}:{{ .HTTPPort }}/${var.variant}/custom.disklabel ; ftp -o /tmp/disk_setup.sh http://{{ .HTTPIP }}:{{ .HTTPPort }}/${var.variant}/disklabel_setup_vmopenbsd.sh ; ftp -o /tmp/install.sh http://{{ .HTTPIP }}:{{ .HTTPPort }}/${var.variant}/${var.vol_mgr}-install.sh ; (cd /dev ; sh MAKEDEV sd0) ; sh -x /tmp/disk_setup.sh part_format ${var.vol_mgr} ; sh -x /tmp/disk_setup.sh mount_filesystems<enter><wait10><wait10><wait10>env REL=${var.REL} sh -x /tmp/install.sh ${var.init_hostname} '${var.passwd_plain}'<enter><wait>"]
  boot_wait            = "10s"
  disk_image           = "true"
  disk_size            = "${var.disk_size}"
  format               = "ova"
  guest_additions_mode = "disable"
  guest_additions_path = "VBoxGuestAdditions_{{ .Version }}.iso"
  guest_os_type        = "OpenBSD_64"
  hard_drive_interface = "sata"
  headless             = "${var.headless}"
  http_directory       = "init"
  iso_checksum         = "file:file://${var.isos_pardir}/openbsd/amd64/SHA256"
  iso_interface        = "sata"
  iso_url              = ""
  iso_urls             = ["file://${var.isos_pardir}/openbsd/${var.iso_name_x64}.img","${var.iso_url_mirror}/${var.iso_url_directory}/${var.iso_name_x64}.img"]
  output_directory     = "output-vms/${var.variant}-x86_64-${var.vol_mgr}"
  shutdown_command     = "shutdown -p +3 || poweroff"
  ssh_password         = "${var.passwd_plain}"
  ssh_timeout          = "2h45m"
  ssh_username         = "root"
  vboxmanage           = [["storagectl", "{{ .Name }}", "--name", "SCSI Controller", "--add", "scsi", "--bootable", "on"], ["modifyvm", "{{ .Name }}", "--firmware", "bios", "--nictype1", "virtio", "--memory", "2048", "--vram", "64", "--rtcuseutc", "on", "--cpus", "2", "--clipboard", "bidirectional", "--draganddrop", "bidirectional", "--accelerate3d", "on", "--groups", "/init_vm"]]
  vm_name              = "${var.variant}-x86_64-${var.vol_mgr}"
}

build {
  sources = ["source.qemu.qemu_aarch64", "source.qemu.qemu_x86_64", "source.virtualbox-iso.virtualbox_x86_64"]

  provisioner "shell-local" {
    inline = ["mkdir -p ${var.home}/.ssh/publish_krls ${var.home}/.pki/publish_crls", "cp -a ${var.home}/.ssh/publish_krls init/common/skel/_ssh/", "cp -a ${var.home}/.pki/publish_crls init/common/skel/_pki/", "tar -cf /tmp/scripts.tar init/common init/${var.variant} -C scripts ${var.variant}"]
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
    source      = "/tmp/scripts.tar"
  }

  provisioner "shell" {
    environment_vars = ["HOME_DIR=/home/packer"]
    execute_command  = "chmod +x {{ .Path }} ; env {{ .Vars }} sh -c {{ .Path }}"
    inline           = ["tar -xf /tmp/scripts.tar -C /tmp ; mv /tmp/${var.variant} /tmp/scripts", "cp -a /tmp/init /tmp/scripts /root/"]
  }

  provisioner "shell" {
    environment_vars = ["HOME_DIR=/home/packer"]
    execute_command  = "chmod +x {{ .Path }} ; env {{ .Vars }} sh -c {{ .Path }}"
    scripts          = ["init/${var.variant}/vagrantuser.sh"]
  }

  provisioner "shell" {
    environment_vars = ["HOME_DIR=/home/packer"]
    execute_command  = "chmod +x {{ .Path }} ; env {{ .Vars }} sh -c {{ .Path }}"
    only             = ["virtualbox-iso.virtualbox_x86_64"]
    scripts          = ["init/common/bsd/zerofill.sh"]
  }

  post-processor "checksum" {
    checksum_types = ["md5", "sha256"]
    only           = ["qemu.qemu_x86_64"]
    output         = "output-vms/${var.variant}-x86_64-${var.vol_mgr}/${var.variant}-x86_64-${var.vol_mgr}.{{ .BuilderType }}.{{ .ChecksumType }}"
  }
  post-processor "vagrant" {
    keep_input_artifact  = true
    include              = ["init/common/info.json", "init/common/qemu_lxc/vmrun.sh", "init/common/qemu_lxc/vmrun_qemu_x86_64.args", "init/common/qemu_lxc/vmrun_bhyve.args", "${var.firmware_qemu_x64}"]
    only                 = ["qemu.qemu_x86_64"]
    output               = "output-vms/${var.variant}-x86_64-${var.vol_mgr}/${var.variant}-x86_64-${var.vol_mgr}-${local.build_timestamp}.{{ .Provider }}.box"
    vagrantfile_template = "Vagrantfile.template"
  }
  post-processor "shell-local" {
    inline = ["mv output-vms/${var.variant}-x86_64-${var.vol_mgr}/${var.variant}-x86_64-${var.vol_mgr} output-vms/${var.variant}-x86_64-${var.vol_mgr}/${var.variant}-x86_64-${var.vol_mgr}.qcow2", "cp -a init/common/qemu_lxc/vmrun.sh output-vms/${var.variant}-x86_64-${var.vol_mgr}/"]
    only   = ["qemu.qemu_x86_64"]
  }
  post-processor "checksum" {
    checksum_types = ["md5", "sha256"]
    only           = ["qemu.qemu_aarch64"]
    output         = "output-vms/${var.variant}-aarch64-${var.vol_mgr}/${var.variant}-aarch64-${var.vol_mgr}.{{ .BuilderType }}.{{ .ChecksumType }}"
  }
  post-processor "vagrant" {
    keep_input_artifact  = true
    include              = ["init/common/info.json", "init/common/qemu_lxc/vmrun.sh", "init/common/qemu_lxc/vmrun_qemu_aarch64.args", "${var.firmware_qemu_aa64}"]
    only                 = ["qemu.qemu_aarch64"]
    output               = "output-vms/${var.variant}-aarch64-${var.vol_mgr}/${var.variant}-aarch64-${var.vol_mgr}-${local.build_timestamp}.{{ .Provider }}.box"
    vagrantfile_template = "Vagrantfile.template"
  }
  post-processor "shell-local" {
    inline = ["mv output-vms/${var.variant}-aarch64-${var.vol_mgr}/${var.variant}-aarch64-${var.vol_mgr} output-vms/${var.variant}-aarch64-${var.vol_mgr}/${var.variant}-aarch64-${var.vol_mgr}.qcow2", "cp -a init/common/qemu_lxc/vmrun.sh output-vms/${var.variant}-aarch64-${var.vol_mgr}/"]
    only   = ["qemu.qemu_aarch64"]
  }
}
