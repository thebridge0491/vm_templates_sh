# usage example: (packer init <dir>[/template.pkr.hcl] ; [PACKER_LOG=1 PACKER_LOG_PATH=/tmp/packer.log] packer build -only=qemu.qemu_x86_64 <dir>[/template.pkr.hcl])

variable "MIRROR" {
  type    = string
  default = ""
}

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
  default = " apparmor=0 "
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
  default = "dnf zypper"
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
  #default = "debian-12.4.0-arm64-netinst"
  default = "netboot/mini"
}

variable "iso_base_x64" {
  type    = string
  #default = "debian-12.4.0-amd64-netinst"
  default = "devuan_daedalus_5.0.1_amd64_netinstall"
}

variable "iso_url_directory_aa64" {
  type    = string
  #default = "/current/arm64/iso-cd"
  default = "/dists/daedalus/main/installer-arm64/current/images"
}

variable "iso_url_directory" {
  type    = string
  #default = "/current/amd64/iso-cd"
  default = "/devuan_daedalus/installer-iso"
}

variable "isolive_base_x64" {
  type    = string
  #default = "debian-live-12.4.0-amd64-standard"
  default = "devuan_daedalus_5.0.0_amd64_minimal-live"
}

variable "isolive_cdlabel_x64" {
  type    = string
  default = "devuan_daedalus_5.0.0_amd64_minimal-live"
}

variable "isolive_url_directory" {
  type    = string
  #default = "/current-live/amd64/iso-hybrid"
  default = "/devuan_daedalus/minimal-live"
}

variable "isos_pardir" {
  type    = string
  default = "/mnt/Data0/distros"
}

variable "mirror_host" {
  type    = string
  #default = "mirror.math.princeton.edu/pub/debian-cd"
  default = "mirror.math.princeton.edu/pub/devuan"
}

variable "mirror_host_aa64" {
  type    = string
  #default = "mirror.math.princeton.edu/pub/debian-cd"
  default = "pkgmaster.devuan.org/devuan"
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
  #default = "/debian"
  default = "/merged"
}

variable "repo_host" {
  type    = string
  #default = "deb.debian.org"
  default = "deb.devuan.org"
}

variable "service_mgr" {
  type    = string
  default = ""
}

variable "variant" {
  type    = string
  default = "debian"
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
  boot_command       = ["<wait5><wait>c<wait>linux /linux ${var.boot_cmdln_options} ", "auto=true preseed/url=http://{{.HTTPIP}}:{{.HTTPPort}}/${var.variant}/${var.vol_mgr}-preseed.cfg hostname=${var.variant}-boxv0000 domain= locale=en_US keymap=us console-setup/ask_detect=false mirror/http/hostname=${var.repo_host} mirror/http/directory=${var.repo_directory} choose-init/select_init=sysvinit<enter>", "initrd /initrd.gz<enter>boot<enter>"]
  boot_wait          = "5s"
  disk_detect_zeroes = "unmap"
  disk_discard       = "unmap"
  disk_interface     = "virtio"
  disk_size          = "${var.disk_size}"
  headless           = "${var.headless}"
  http_directory     = "init"
  iso_checksum       = "file:file://${var.isos_pardir}/debian/arm64/SHA256SUMS"
  iso_url            = ""
  iso_urls           = ["file://${var.isos_pardir}/debian/${var.iso_base_aa64}.iso","https://${var.mirror_host_aa64}${var.iso_url_directory_aa64}/${var.iso_base_aa64}.iso"]
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
  #boot_command       = ["<down><up><wait>c<wait>linux /live/vmlinuz ${var.boot_cmdln_options} boot=live components username=devuan textmode=1 text 3<enter>initrd /live/initrd.img<enter>boot<enter>", "<wait10><wait10><wait10><wait10><wait10><wait10>", "<wait10><wait10><wait10><wait10><wait10><wait10>", "<wait10><wait10><wait10><wait10><wait10><wait10>", "<enter>devuan<enter>devuan<enter>sudo su<enter>ip link ; sleep 3 ; dhcpcd eth0 ; dhclient eth0 ; systemctl stop ssh ; systemctl status ssh ; invoke-rc.d ssh stop ; invoke-rc.d ssh status<enter>sleep 3 ; . /etc/os-release ; mount -o remount,size=1500M /run/live/overlay ; df -h ; sleep 5 ; sed -i '/main.*$/ s|main.*$|main contrib non-free|' /etc/apt/sources.list ; apt-get --yes update --allow-releaseinfo-change ; apt-get --yes install ${var.foreign_pkgmgr} gdisk lvm2 btrfs-progs ; ", "if [ 'zfs' = '${var.vol_mgr}' ] ; then . /etc/os-release ; sed -i 's|^#deb|deb|g' /etc/apt/sources.list ; apt-get --yes update ; apt-get --yes install --no-install-recommends linux-headers-$(uname -r) ; apt-get --yes install -t $${VERSION_CODENAME/ */}-backports --no-install-recommends zfs-dkms zfsutils-linux zfs-initramfs ; fi ; ", "cd /tmp ; wget 'http://{{.HTTPIP}}:{{.HTTPPort}}/common/disk_setup.sh' 'http://{{.HTTPIP}}:{{.HTTPPort}}/${var.variant}/install.sh' ; env MKFS_CMD=${var.mkfs_cmd} sh -x /tmp/disk_setup.sh part_format sgdisk ${var.vol_mgr} ; sh -x /tmp/disk_setup.sh mount_filesystems ${var.vol_mgr}<enter><wait10><wait10><wait10>env MIRROR=${var.MIRROR} RELEASE=${var.RELEASE} VOL_MGR=${var.vol_mgr} service_mgr=${var.service_mgr} sh -x /tmp/install.sh run_install ${var.variant}-boxv0000 '${var.passwd_crypted}'<enter><wait>"]

  #boot_command       = ["<wait5><wait>c<wait>linux /linux ${var.boot_cmdln_options} ", "auto=true preseed/url=http://{{.HTTPIP}}:{{.HTTPPort}}/${var.variant}/${var.vol_mgr}-preseed.cfg hostname=${var.variant}-boxv0000 domain= locale=en_US keymap=us console-setup/ask_detect=false mirror/http/hostname=${var.repo_host} mirror/http/directory=${var.repo_directory} choose-init/select_init=sysvinit<enter>", "initrd /initrd.gz<enter>boot<enter>"]

  boot_command       = ["<wait10><down><tab><wait30>/boot/isolinux/linux ${var.boot_cmdln_options} ", "auto=true preseed/url=http://{{.HTTPIP}}:{{.HTTPPort}}/${var.variant}/${var.vol_mgr}-preseed.cfg hostname=${var.variant}-boxv0000 domain= locale=en_US keymap=us console-setup/ask_detect=false mirror/http/hostname=${var.repo_host} mirror/http/directory=${var.repo_directory} choose-init/select_init=sysvinit initrd=/boot/isolinux/initrd.gz<enter>"]

  boot_wait          = "10s"
  disk_detect_zeroes = "unmap"
  disk_discard       = "unmap"
  disk_interface     = "virtio-scsi"
  disk_size          = "${var.disk_size}"
  headless           = "${var.headless}"
  http_directory     = "init"
  iso_checksum       = "file:file://${var.isos_pardir}/debian/SHA256SUMS.txt"
  iso_url            = ""
  iso_urls           = ["file://${var.isos_pardir}/debian/${var.iso_base_x64}.iso","https://${var.mirror_host}${var.iso_url_directory}/${var.iso_base_x64}.iso"]
  machine_type       = "q35"
  net_bridge         = "${var.qemunet_bridge}"
  output_directory   = "output-vms/${var.variant}-x86_64-${var.vol_mgr}"
  qemuargs           = [["-cpu", "SandyBridge"], ["-smp", "cpus=2"], ["-m", "size=2048"], ["-boot", "order=cdn,menu=on"], ["-name", "{{.Name}}"], ["-device", "virtio-net,netdev=user.0,mac=52:54:00:${local.mac_last3}"], ["-device", "virtio-scsi"], ["-device", "scsi-hd,drive=drive0"], ["-usb"], ["-vga", "virtio"], ["-display", "gtk,show-cursor=on"], ["-smbios", "type=0,uefi=on"], ["-bios", "${var.firmware_qemu_x64}"], ["-virtfs", "${var.virtfs_opts}"]]
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
