# OS variant oriented vars
# ----------
variable "variant" {
  type    = string
  default = "mageia"
}

variable "vol_mgr" {
  type    = string
  default = "std"
}

variable "mirror_host_x64" {
  type    = string
  default = "mirrors.kernel.org/mageia"
}

variable "repo_directory_x64" {
  type    = string
  default = "/distrib/9/x86_64"
}

variable "iso_url_directory_x64" {
  type    = string
  default = "/iso/9/Mageia-9-Live-Xfce-x86_64"
  #default = "/distrib/9/x86_64/install/images"
}

variable "iso_base_x64" {
  type    = string
  default = "live/Mageia-9-Live-Xfce-x86_64"
  #default = "Mageia-9-netinstall-x86_64"
}

variable "iso_cdlabel_x64" {
  type    = string
  default = "Mageia-9-Live-Xfce-x86_64"
  #default = "Mageia-9-x86_64-netinstall"
}

variable "mirror_host_aa64" {
  type    = string
  default = null
}

variable "iso_url_directory_aa64" {
  type    = string
  default = null
}

variable "iso_base_aa64" {
  type    = string
  default = null
}

variable "boot_cmdln_options" {
  type    = string
  default = " video=1024x768 nomodeset "
}


# Builder common vars
# ----------
variable "author" {
  type    = string
  default = "thebridge0491"
}
