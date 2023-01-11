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
  default = "--repository=https://dl-cdn.alpinelinux.org/alpine/v3.13/main debootstrap=1.0.123-r0 pacman"
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
  default = "alpine-boxv0000"
}

variable "iso_name_aa64" {
  type    = string
  default = "alpine-standard-3.17.0-aarch64"
}

variable "iso_name_x64" {
  type    = string
  default = "alpine-extended-3.17.0-x86_64"
}

variable "iso_url_directory" {
  type    = string
  default = "latest-stable/releases"
}

variable "iso_url_mirror" {
  type    = string
  default = "https://dl-cdn.alpinelinux.org/alpine"
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
  default = "$6$16CHARACTERSSALT$A4i3yeafzCxgDj5imBx2ZdMWnr9LGzn3KihP9Dz0zTHbxw31jJGEuuJ6OB6Blkkw0VSUkQzSjE9n4iAAnl0RQ1"
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

variable "repo_host" {
  type    = string
  default = "dl-cdn.alpinelinux.org/alpine"
}

variable "variant" {
  type    = string
  default = "alpine"
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
  mac_last3          = "${formatdate("hh:mm:ss", timestamp())}"
}

source "qemu" "qemu_aarch64" {
  boot_command       = ["<wait10><wait10><wait10><wait10><wait10><wait10>", "<wait10><wait10><wait10><wait10><wait10><wait10>", "<wait10><wait10><wait10><wait10><wait10><wait10>", "<wait10><wait10><wait10><wait10><wait10><wait10>", "<wait10><wait10><wait10><wait10><wait10><wait10>", "<wait10>root<enter><wait>ifconfig eth0 up ; udhcpc -i eth0<enter><wait10>", "<wait10><wait10><wait10><wait10><wait10><wait10>", "date +%Y.%m.%d-%H:%M -s '${local.datestamp}-23:59' ; wget -O /tmp/disk_setup.sh 'http://{{ .HTTPIP }}:{{ .HTTPPort }}/common/disk_setup_vmlinux.sh' ; wget -O /tmp/install.sh 'http://{{ .HTTPIP }}:{{ .HTTPPort }}/${var.variant}/${var.vol_mgr}-install.sh' ; . /etc/os-release ; echo http://${var.repo_host}/v$(cat /etc/alpine-release | cut -d. -f1-2)/main >> /etc/apk/repositories ; echo http://${var.repo_host}/v$(cat /etc/alpine-release | cut -d. -f1-2)/community >> /etc/apk/repositories ; apk update ; apk add ${var.foreign_pkgmgr} e2fsprogs xfsprogs dosfstools sgdisk libffi gnupg curl lvm2 btrfs-progs util-linux multipath-tools perl ; ", "if [ 'zfs' = '${var.vol_mgr}' ] ; then apk add zfs ; sleep 5 ; fi ; ", "setup-devd udev ; sleep 3 ; env MKFS_CMD=${var.mkfs_cmd} sh -x /tmp/disk_setup.sh part_format sgdisk ${var.vol_mgr} ; sh -x /tmp/disk_setup.sh mount_filesystems ${var.vol_mgr}<enter><wait10><wait10><wait10>env RELEASE=${var.RELEASE} sh -x /tmp/install.sh ${var.init_hostname} '${var.passwd_crypted}'<enter><wait>"]
  boot_wait          = "10s"
  disk_detect_zeroes = "unmap"
  disk_discard       = "unmap"
  disk_interface     = "virtio"
  disk_size          = "${var.disk_size}"
  headless           = "${var.headless}"
  http_directory     = "init"
  iso_checksum       = "file:file://${var.isos_pardir}/alpine/${var.iso_name_aa64}.iso.sha256"
  iso_url            = ""
  iso_urls           = ["file://${var.isos_pardir}/alpine/${var.iso_name_aa64}.iso","${var.iso_url_mirror}/${var.iso_url_directory}/aarch64/${var.iso_name_aa64}.iso"]
  machine_type       = "virt"
  net_bridge         = "${var.qemunet_bridge}"
  output_directory   = "output-vms/${var.variant}-aarch64-${var.vol_mgr}"
  qemu_binary        = "qemu-system-aarch64"
  qemuargs           = [["-cpu", "cortex-a57"], ["-machine", "virt,gic-version=3,acpi=off"], ["-smp", "cpus=2"], ["-m", "size=2048"], ["-boot", "order=cdn,menu=on"], ["-name", "{{ .Name }}"], ["-device", "virtio-net,netdev=user.0,mac=52:54:00:${local.mac_last3}"], ["-device", "qemu-xhci,id=usb"], ["-usb"], ["-device", "usb-kbd"], ["-device", "usb-tablet"], ["-vga", "none"], ["-device", "virtio-gpu-pci"], ["-display", "gtk,show-cursor=on"], ["-smbios", "type=0,uefi=on"], ["-bios", "${var.firmware_qemu_aa64}"], ["-virtfs", "${var.virtfs_opts}"]]
  shutdown_command   = "sudo shutdown -hP +3 || sudo poweroff"
  ssh_password       = "${var.passwd_plain}"
  ssh_timeout        = "4h45m"
  ssh_username       = "packer"
  vm_name            = "${var.variant}-aarch64-${var.vol_mgr}"
}

source "qemu" "qemu_x86_64" {
  #boot_command         = ["root<enter><wait>ifconfig eth0 up ; udhcpc -i eth0<enter><wait10>", "date +%Y.%m.%d-%H:%M -s '${local.datestamp}-23:59' ; wget -O /tmp/answers 'http://{{ .HTTPIP }}:{{ .HTTPPort }}/${var.variant}/${var.vol_mgr}-answers' ; wget -O /tmp/post_autoinstall.sh 'http://{{ .HTTPIP }}:{{ .HTTPPort }}/${var.variant}/${var.vol_mgr}-post_autoinstall.sh' ; service sshd stop ; APKREPOSOPTS=http://${var.repo_host}/v$(cat /etc/alpine-release | cut -d. -f1-2)/main BOOT_SIZE=200 USE_EFI=1 setup-alpine -f /tmp/answers<enter><wait5>${var.passwd_plain}<enter>${var.passwd_plain}<enter><wait10><wait10><wait10>y<enter><wait10><wait10><wait10>env RELEASE=${var.RELEASE} sh -x /tmp/post_autoinstall.sh '${var.passwd_crypted}'<enter>"]

  boot_command       = ["<wait10>root<enter><wait>ifconfig eth0 up ; udhcpc -i eth0<enter><wait10>", "<wait10><wait10><wait10><wait10><wait10><wait10>", "date +%Y.%m.%d-%H:%M -s '${local.datestamp}-23:59' ; wget -O /tmp/disk_setup.sh 'http://{{ .HTTPIP }}:{{ .HTTPPort }}/common/disk_setup_vmlinux.sh' ; wget -O /tmp/install.sh 'http://{{ .HTTPIP }}:{{ .HTTPPort }}/${var.variant}/${var.vol_mgr}-install.sh' ; . /etc/os-release ; echo http://${var.repo_host}/v$(cat /etc/alpine-release | cut -d. -f1-2)/main >> /etc/apk/repositories ; echo http://${var.repo_host}/v$(cat /etc/alpine-release | cut -d. -f1-2)/community >> /etc/apk/repositories ; apk update ; apk add ${var.foreign_pkgmgr} e2fsprogs xfsprogs dosfstools sgdisk libffi gnupg curl lvm2 btrfs-progs util-linux multipath-tools perl ; ", "if [ 'zfs' = '${var.vol_mgr}' ] ; then apk add zfs ; sleep 5 ; fi ; ", "setup-devd udev ; sleep 3 ; env MKFS_CMD=${var.mkfs_cmd} sh -x /tmp/disk_setup.sh part_format sgdisk ${var.vol_mgr} ; sh -x /tmp/disk_setup.sh mount_filesystems ${var.vol_mgr}<enter><wait10><wait10><wait10>env RELEASE=${var.RELEASE} sh -x /tmp/install.sh ${var.init_hostname} '${var.passwd_crypted}'<enter><wait>"]

  boot_wait          = "10s"
  disk_detect_zeroes = "unmap"
  disk_discard       = "unmap"
  disk_interface     = "virtio-scsi"
  disk_size          = "${var.disk_size}"
  headless           = "${var.headless}"
  http_directory     = "init"
  iso_checksum       = "file:file://${var.isos_pardir}/alpine/${var.iso_name_x64}.iso.sha256"
  iso_url            = ""
  iso_urls           = ["file://${var.isos_pardir}/alpine/${var.iso_name_x64}.iso","${var.iso_url_mirror}/${var.iso_url_directory}/x86_64/${var.iso_name_x64}.iso"]
  machine_type       = "q35"
  net_bridge         = "${var.qemunet_bridge}"
  output_directory   = "output-vms/${var.variant}-x86_64-${var.vol_mgr}"
  qemuargs           = [["-cpu", "SandyBridge"], ["-smp", "cpus=2"], ["-m", "size=2048"], ["-boot", "order=cdn,menu=on"], ["-name", "{{ .Name }}"], ["-device", "virtio-net,netdev=user.0,mac=52:54:00:${local.mac_last3}"], ["-device", "virtio-scsi"], ["-device", "scsi-hd,drive=drive0"], ["-usb"], ["-vga", "none"], ["-device", "qxl-vga,vgamem_mb=64"], ["-display", "gtk,show-cursor=on"], ["-smbios", "type=0,uefi=on"], ["-bios", "${var.firmware_qemu_x64}"], ["-virtfs", "${var.virtfs_opts}"]]
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
    except           = ["qemu.qemu_x86_64", "qemu.qemu_aarch64"]
    scripts          = ["init/common/linux/zerofill.sh"]
  }

  post-processor "checksum" {
    checksum_types = ["sha256"]
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
    checksum_types = ["sha256"]
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
