# usage: (export mypass=$(python -c 'import getpass ; print(getpass.getpass())') ; packer init <dir>[/template.pkr.hcl] ; packer build -var passwd_plain=${mypass} -var passwd_crypted=$(python -c 'import os,crypt ; print(crypt.crypt(os.getenv("mypass"), "$6$16CHARACTERSSALT"))') -only=[qemu.qemu_x86_64|virtualbox-iso.virtualbox_x86_64] <dir>[/template.pkr.hcl])

variable "author" {
  type    = string
  default = "thebridge0491"
}

variable "boot_cmdln_options" {
  type    = string
  default = "nokmsboot noacpi nomodeset video=1024x768 keyb=us "
}

variable "disk_size" {
  type    = string
  default = "30720"
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
  default = "pclinuxos-boxv0000"
}

variable "iso_name_x64" {
  type    = string
  default = "pclinuxos64-xfce-2022.11.30"
}

variable "iso_url_directory" {
  type    = string
  default = "pclinuxos/live-cd/64bit"
}

variable "iso_url_mirror" {
  type    = string
  default = "https://spout.ussg.indiana.edu/linux/pclinuxos"
}

variable "isos_pardir" {
  type    = string
  default = "/mnt/Data0/distros"
}

variable "mkfs_cmd" {
  type    = string
  default = "mkfs.ext4"
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
  default = "pclinuxos"
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
}

source "qemu" "qemu_x86_64" {
  boot_command       = ["<wait>c<wait>linux /isolinux/vmlinuz livecd=livecd root=/dev/rd/3 keyb=us<enter>initrd /isolinux/initrd.gz<enter>boot<enter>", "<wait10><wait10><wait10><wait10><wait10><wait10>", "<wait10><wait10><wait10><wait10><wait10><wait10>", "<wait10><wait10><wait10><wait10><wait10><wait10>", "<wait10><wait10><wait10><wait10><wait10><wait10>", "<wait10><wait10><wait10><wait10><wait10><wait10><enter>", "guest<enter><enter><wait10>su<enter><wait10>apt-get update ; apt-get install -y netcat gdisk efibootmgr lvm2 btrfs-progs ; apt-get -y --fix-broken install ; ", "cd /tmp ; wget -O /tmp/disk_setup.sh 'http://{{ .HTTPIP }}:{{ .HTTPPort }}/common/disk_setup_vmlinux.sh' ; wget -O /tmp/post_install.sh 'http://{{ .HTTPIP }}:{{ .HTTPPort }}/${var.variant}/${var.vol_mgr}-post_drakliveinstall.sh' ; env MKFS_CMD=${var.mkfs_cmd} sh -x /tmp/disk_setup.sh part_format sgdisk ${var.vol_mgr} ; echo '' ; echo '(btrfs) USE Custom partitioning in draklive-install WITH Mount options advanced for / (root): subvol=@' ; echo '' ; sleep 30 ; draklive-install --expert --noauto ; sh -x /tmp/post_install.sh ${var.init_hostname} '${var.passwd_plain}'<enter><wait>"]
  boot_wait          = "10s"
  disk_detect_zeroes = "unmap"
  disk_discard       = "unmap"
  disk_interface     = "virtio-scsi"
  disk_size          = "${var.disk_size}"
  headless           = "${var.headless}"
  http_directory     = "init"
  iso_checksum       = "file:file://${var.isos_pardir}/pclinuxos/${var.iso_name_x64}.md5sum"
  iso_url            = ""
  iso_urls           = ["file://${var.isos_pardir}/pclinuxos/${var.iso_name_x64}.iso","${var.iso_url_mirror}/${var.iso_url_directory}/${var.iso_name_x64}.iso"]
  machine_type       = "q35"
  output_directory   = "output-vms/${var.variant}-x86_64-${var.vol_mgr}"
  qemuargs           = [["-smp", "cpus=2"], ["-m", "size=2048"], ["-boot", "order=cdn,menu=on"], ["-name", "{{ .Name }}"], ["-device", "virtio-net,netdev=user.0"], ["-device", "virtio-scsi"], ["-device", "scsi-hd,drive=drive0"], ["-usb"], ["-vga", "none"], ["-device", "qxl-vga,vgamem_mb=64"], ["-display", "gtk,show-cursor=on"], ["-smbios", "type=0,uefi=on"], ["-bios", "${var.firmware_qemu_x64}"], ["-virtfs", "${var.virtfs_opts}"]]
  shutdown_command   = "sudo shutdown -hP +3 || sudo poweroff"
  ssh_password       = "${var.passwd_plain}"
  ssh_timeout        = "2h45m"
  ssh_username       = "packer"
  vm_name            = "${var.variant}-x86_64-${var.vol_mgr}"
}

source "virtualbox-iso" "virtualbox_x86_64" {
  boot_command         = ["<wait>c<wait>linux /isolinux/vmlinuz livecd=livecd root=/dev/rd/3 keyb=us<enter>initrd /isolinux/initrd.gz<enter>boot<enter>", "<wait10><wait10><wait10><wait10><wait10><wait10>", "<wait10><wait10><wait10><wait10><wait10><wait10>", "<wait10><wait10><wait10><wait10><wait10><wait10>", "<wait10><wait10><wait10><wait10><wait10><wait10>", "<wait10><wait10><wait10><wait10><wait10><wait10><enter>", "guest<enter><enter><wait10>su<enter><wait10>apt-get update ; apt-get install -y netcat gdisk efibootmgr lvm2 btrfs-progs ; apt-get -y --fix-broken install ; ", "cd /tmp ; wget -O /tmp/disk_setup.sh 'http://{{ .HTTPIP }}:{{ .HTTPPort }}/common/disk_setup_vmlinux.sh' ; wget -O /tmp/post_install.sh 'http://{{ .HTTPIP }}:{{ .HTTPPort }}/${var.variant}/${var.vol_mgr}-post_drakliveinstall.sh' ; env MKFS_CMD=${var.mkfs_cmd} sh -x /tmp/disk_setup.sh part_format sgdisk ${var.vol_mgr} ; echo '' ; echo '(btrfs) USE Custom partitioning in draklive-install WITH Mount options advanced for / (root): subvol=@' ; echo '' ; sleep 30 ; draklive-install --expert --noauto ; sh -x /tmp/post_install.sh ${var.init_hostname} '${var.passwd_plain}'<enter><wait>"]
  boot_wait            = "10s"
  disk_size            = "${var.disk_size}"
  format               = "ova"
  guest_additions_mode = "disable"
  guest_additions_path = "VBoxGuestAdditions_{{ .Version }}.iso"
  guest_os_type        = "Mandriva_64"
  hard_drive_interface = "sata"
  headless             = "${var.headless}"
  http_directory       = "init"
  iso_checksum         = "file:file://${var.isos_pardir}/pclinuxos/${var.iso_name_x64}.md5sum"
  iso_interface        = "sata"
  iso_url              = ""
  iso_urls             = ["file://${var.isos_pardir}/pclinuxos/${var.iso_name_x64}.iso","${var.iso_url_mirror}/${var.iso_url_directory}/${var.iso_name_x64}.iso"]
  output_directory     = "output-vms/${var.variant}-x86_64-${var.vol_mgr}"
  shutdown_command     = "sudo shutdown -hP +3 || sudo poweroff"
  ssh_password         = "${var.passwd_plain}"
  ssh_timeout          = "2h45m"
  ssh_username         = "packer"
  vboxmanage           = [["storagectl", "{{ .Name }}", "--name", "SCSI Controller", "--add", "scsi", "--bootable", "on"], ["modifyvm", "{{ .Name }}", "--firmware", "efi", "--nictype1", "virtio", "--memory", "2048", "--vram", "64", "--rtcuseutc", "on", "--cpus", "2", "--clipboard", "bidirectional", "--draganddrop", "bidirectional", "--accelerate3d", "on", "--groups", "/init_vm"], ["sharedfolder", "add", "{{ .Name }}", "--name", "9p_Data0", "--hostpath", "/mnt/Data0", "--automount"]]
  vm_name              = "${var.variant}-x86_64-${var.vol_mgr}"
}

build {
  sources = ["source.qemu.qemu_x86_64", "source.virtualbox-iso.virtualbox_x86_64"]

  provisioner "shell-local" {
    inline = ["mkdir -p ${var.home}/.ssh/publish_krls ${var.home}/.pki/publish_crls", "cp -a ${var.home}/.ssh/publish_krls init/common/skel/_ssh/", "cp -a ${var.home}/.pki/publish_crls init/common/skel/_pki/", "tar -cf /tmp/scripts.tar init/common init/${var.variant} -C scripts ${var.variant}"]
  }

  provisioner "shell-local" {
    inline = ["if command -v erb > /dev/null ; then", "erb author=${var.author} guest=${var.variant}-x86_64-${var.vol_mgr} datestamp=${local.build_timestamp} init/common/catalog.json.erb > output-vms/${var.variant}-x86_64-${var.vol_mgr}/${var.variant}-x86_64-${var.vol_mgr}_catalog.json", "elif command -v pystache > /dev/null ; then", "pystache init/common/catalog.json.mustache '{\"author\":\"${var.author}\",\"guest\":\"${var.variant}-x86_64-${var.vol_mgr}\",\"datestamp\":\"${local.build_timestamp}\"}' > output-vms/${var.variant}-x86_64-${var.vol_mgr}/${var.variant}-x86_64-${var.vol_mgr}_catalog.json", "fi"]
    only   = ["qemu.qemu_x86_64"]
  }

  provisioner "file" {
    destination = "/tmp/scripts.tar"
    generated   = true
    source      = "/tmp/scripts.tar"
  }

  provisioner "shell" {
    environment_vars = ["HOME_DIR=/home/packer"]
    execute_command  = "env {{ .Vars }} sudo sh -x '{{ .Path }}'"
    inline           = ["tar -xf /tmp/scripts.tar -C /tmp ; mv /tmp/${var.variant} /tmp/scripts", "cp -a /tmp/init /tmp/scripts /root/"]
  }

  provisioner "shell" {
    environment_vars = ["HOME_DIR=/home/packer"]
    execute_command  = "env {{ .Vars }} sudo -E sh -eux '{{ .Path }}'"
    scripts          = ["init/${var.variant}/vagrantuser.sh"]
  }

  provisioner "shell" {
    environment_vars = ["HOME_DIR=/home/packer"]
    execute_command  = "env {{ .Vars }} sudo -E sh -eux '{{ .Path }}'"
    only             = ["virtualbox-iso.virtualbox_x86_64"]
    scripts          = ["init/common/linux/zerofill.sh"]
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
}
