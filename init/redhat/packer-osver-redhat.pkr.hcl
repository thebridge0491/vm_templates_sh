# OS variant oriented vars
# ----------
variable "variant" {
  type    = string
  default = "redhat"
}

variable "vol_mgr" {
  type    = string
  default = "std"
}

variable "mirror_host_x64" {
  type    = string
  #default = "mirror.stream.centos.org"
  #default = "repo.almalinux.org/almalinux"
  default = "dl.rockylinux.org/pub/rocky"
}

variable "repo_directory_x64" {
  type    = string
  #default = "/9-stream/BaseOS/x86_64/os"
  default = "/9/BaseOS/x86_64/os"
}

variable "iso_url_directory_x64" {
  type    = string
  #default = "/SIGs/9-stream/altimages/images/live/x86_64"
  ##default = "/9-stream/BaseOS/x86_64/iso"
  default = "/9/live/x86_64"
  #default = "/9/isos/x86_64"
}

variable "iso_base_x64" {
  type    = string
  #default = "live/CentOS-Stream-Image-MIN-Live.x86_64-9-202510080808"
  ##default = "CentOS-Stream-9-latest-x86_64-boot"
  #default = "live/AlmaLinux-9-latest-x86_64-Live-XFCE"
  default = "live/Rocky-9-XFCE-x86_64-latest"
  #default = "Rocky-9-latest-x86_64-boot"
}

variable "iso_cdlabel_x64" {
  type    = string
  #default = "CentOS_AltImage"
  ##default = "CentOS-Stream-9-BaseOS-x86_64"
  #default = "AlmaLinux-9.7-x86_64-Live-XFCE"
  default = "Rocky-9-7-XFCE"
}

variable "mirror_host_aa64" {
  type    = string
  #default = "mirror.stream.centos.org"
  #default = "repo.almalinux.org/almalinux"
  default = "dl.rockylinux.org/pub/rocky"
}

variable "repo_directory_aa64" {
  type    = string
  #default = "/9-stream/BaseOS/aarch64/os"
  default = "/9/BaseOS/aarch64/os"
}

variable "iso_url_directory_aa64" {
  type    = string
  #default = "/SIGs/9-stream/altimages/images/live/aarch64"
  ##default = "/9-stream/BaseOS/aarch64/iso"
  default = "/9/live/aarch64"
  #default = "/9/isos/aarch64"
}

variable "iso_base_aa64" {
  type    = string
  #default = "live/aarch64/CentOS-Stream-Image-MIN-Live.aarch64-9-202510080808"
  ##default = "aarch64/CentOS-Stream-9-latest-aarch64-boot"
  #default = "live/AlmaLinux-9-latest-aarch64-Live-XFCE"
  default = "live/aarch64/Rocky-9-XFCE-aarch64-latest"
  #default = "aarch64/Rocky-9-latest-aarch64-boot"
}

variable "iso_cdlabel_aa64" {
  type    = string
  #default = "CentOS_AltImage"
  ##default = "CentOS-Stream-9-BaseOS-aarch64"
  default = "Rocky-9-7-XFCE-aarch64"
  #default = "Rocky-9-7-aarch64-dvd"
}

variable "boot_cmdln_options" {
  type    = string
  default = " quiet video=1024x768 nomodeset "
}


# Builder common vars
# ----------
variable "author" {
  type    = string
  default = "thebridge0491"
}
