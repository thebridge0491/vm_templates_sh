# usage: packer build [-var machine=x86_64] [-var variant=freebsd] [-var vm_name=freebsd-x86_64-std] [-var author=thebridge0491] [-var build_timestamp=???] -only=[null.box-libvirt|null.box-bhyve] <dir>[/box-vagrant.pkr.hcl]

variable "author" {
  type    = string
  default = "thebridge0491"
}

variable "firmware_bhyve_x64" {
  type    = string
  default = "/usr/local/share/uefi-firmware/BHYVE_UEFI_CODE.fd"
}

variable "machine" {
  type    = string
  default = "x86_64"
}

variable "firmware_qemu_aa64" {
  type    = string
  default = "/usr/share/AAVMF/AAVMF_CODE.fd"
}

variable "firmware_qemu_x64" {
  type    = string
  default = "/usr/share/OVMF/OVMF_CODE.fd"
}

variable "variant" {
  type    = string
  default = "freebsd"
}

variable "vm_name" {
  type    = string
  default = "freebsd-x86_64-std"
}

locals {
  #build_timestamp = "${legacy_isotime("2006.01")}"
  #datestamp       = "${legacy_isotime("2006.01.02")}"
  build_timestamp  = "${formatdate("YYYY.MM", timestamp())}"
  datestamp        = "${formatdate("YYYY.MM.DD", timestamp())}"
}

source "null" "box-bhyve" {
  communicator = "none"
}

source "null" "box-libvirt" {
  communicator = "none"
}

build {
  sources = ["source.null.box-bhyve", "source.null.box-libvirt"]

  provisioner "shell-local" {
    inline = ["cp -a init/common/metadata_libvirt.json output-vms/${var.vm_name}/metadata.json", "if [ 'aarch64' = '${var.machine}'] ; then", "cp -a ${var.firmware_qemu_aa64} output-vms/${var.vm_name}/", "else", "cp -a ${var.firmware_qemu_x64} output-vms/${var.vm_name}/", "fi", "cp -a init/common/info.json init/common/qemu_lxc/vmrun* output-vms/${var.vm_name}/", "if command -v erb > /dev/null ; then", "erb author=${var.author} guest=${var.vm_name} datestamp=${local.build_timestamp} init/common/catalog.json.erb > output-vms/${var.vm_name}/${var.vm_name}_catalog.json", "erb variant=${var.variant} init/common/Vagrantfile_libvirt.erb > output-vms/${var.vm_name}/Vagrantfile", "elif command -v chevron > /dev/null ; then", "echo '{\"author\":\"${var.author}\",\"guest\":\"${var.vm_name}\",\"datestamp\":\"${local.build_timestamp}\"}' | chevron -d /dev/stdin init/common/catalog.json.mustache > output-vms/${var.vm_name}/${var.vm_name}_catalog.json", "echo '{\"variant\":\"${var.variant}\"}' | chevron -d /dev/stdin init/common/Vagrantfile_libvirt.mustache > output-vms/${var.vm_name}/Vagrantfile", "elif command -v pystache > /dev/null ; then", "pystache init/common/catalog.json.mustache '{\"author\":\"${var.author}\",\"guest\":\"${var.vm_name}\",\"datestamp\":\"${local.build_timestamp}\"}' > output-vms/${var.vm_name}/${var.vm_name}_catalog.json", "pystache init/common/Vagrantfile_libvirt.mustache '{\"variant\":\"${var.variant}\"}' > output-vms/${var.vm_name}/Vagrantfile", "fi", "cd output-vms/${var.vm_name}", "qemu-img convert -f qcow2 -O qcow2 ${var.vm_name}.qcow2 box.img", "tar -cvzf ${var.vm_name}-${local.build_timestamp}.libvirt.box metadata.json info.json Vagrantfile `ls vmrun* *_CODE.fd` box.img"]
    only   = ["null.box-libvirt"]
  }

  provisioner "shell-local" {
    inline = ["cp -a init/common/metadata_bhyve.json output-vms/${var.vm_name}/metadata.json", "cp -a init/common/info.json init/common/qemu_lxc/vmrun* ${var.firmware_bhyve_x64} output-vms/${var.vm_name}/", "if command -v erb > /dev/null ; then", "erb author=${var.author} guest=${var.vm_name} datestamp=${local.build_timestamp} init/common/catalog.json.erb > output-vms/${var.vm_name}/${var.vm_name}_catalog.json", "erb variant=${var.variant} init/common/Vagrantfile_bhyve.erb > output-vms/${var.vm_name}/Vagrantfile", "elif command -v chevron > /dev/null ; then", "echo '{\"author\":\"${var.author}\",\"guest\":\"${var.vm_name}\",\"datestamp\":\"${local.build_timestamp}\"}' | chevron -d /dev/stdin init/common/catalog.json.mustache > output-vms/${var.vm_name}/${var.vm_name}_catalog.json", "echo '{\"variant\":\"${var.variant}\"}' | chevron -d /dev/stdin init/common/Vagrantfile_bhyve.mustache > output-vms/${var.vm_name}/Vagrantfile", "elif command -v pystache > /dev/null ; then", "pystache init/common/catalog.json.mustache '{\"author\":\"${var.author}\",\"guest\":\"${var.vm_name}\",\"datestamp\":\"${local.build_timestamp}\"}' > output-vms/${var.vm_name}/${var.vm_name}_catalog.json", "pystache init/common/Vagrantfile_bhyve.mustache '{\"variant\":\"${var.variant}\"}' > output-vms/${var.vm_name}/Vagrantfile", "fi", "cd output-vms/${var.vm_name}", "mv ${var.vm_name}.raw box.img", "tar -cvzf ${var.vm_name}-${local.build_timestamp}.bhyve.box metadata.json info.json Vagrantfile `ls vmrun* *_CODE.fd` box.img"]
    only   = ["null.box-bhyve"]
  }

}
