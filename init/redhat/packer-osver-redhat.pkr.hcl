# OS variant oriented vars
# ----------
variable "variant" {
  type    = string
  default = "redhat"
}

variable "osver" {
  type    = string
  default = "9"
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
  #default = "/9/live/x86_64"
  #default = "/9-stream/BaseOS/x86_64/iso"
  default = "/9/isos/x86_64"
}

variable "iso_base_x64" {
  type    = string
  ##default = "AlmaLinux-9.4-x86_64-Live-XFCE"
  #default = "Rocky-9.4-XFCE-x86_64-20240506.0"
  #default = "CentOS-Stream-9-latest-x86_64-boot"
  #default = "AlmaLinux-9.4-x86_64-boot"
  default = "Rocky-9.4-x86_64-boot"
}

variable "iso_cdlabel_x64" {
  type    = string
  #default = "AlmaLinux-9.4-x86_64-Live-XFCE"
  default = "Rocky-9-4-XFCE"
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
  #default = "/9/live/aarch64"
  #default = "/9-stream/BaseOS/aarch64/iso"
  default = "/9/isos/aarch64"
}

variable "iso_base_aa64" {
  type    = string
  #default = "CentOS-Stream-9-latest-aarch64-boot"
  #default = "AlmaLinux-9.4-aarch64-boot"
  default = "Rocky-9.4-aarch64-boot"
}

variable "iso_cdlabel_aa64" {
  type    = string
  #default = "Rocky-9-4-aarch64-dvd"
  default = "Rocky-9-4-XFCE-aarch64"
}

variable "boot_cmdln_options" {
  type    = string
  default = " quiet nomodeset video=1024x768 "
}


# Builder common vars
# ----------
variable "author" {
  type    = string
  default = "thebridge0491"
}
