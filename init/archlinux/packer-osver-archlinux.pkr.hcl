# OS variant oriented vars
# ----------
variable "variant" {
  type    = string
  default = "archlinux"
}

variable "osver" {
  type    = string
  default = "rolling"
}

variable "vol_mgr" {
  type    = string
  default = "std"
}

variable "mirror_host_x64" {
  type    = string
  #default = "mirror.rackspace.com"
  default = "download.artixlinux.org"
}

variable "iso_url_directory_x64" {
  type    = string
  #default = "/archlinux/iso/latest"
  default = "/iso"
}

variable "iso_base_x64" {
  type    = string
  #default = "archlinux-x86_64"
  #default = "artix-base-runit-20240823-x86_64"
  default = "artix-buildiso-runit-20221220-x86_64"
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
  default = " quiet video=1024x768 "
}


# Builder common vars
# ----------
variable "author" {
  type    = string
  default = "thebridge0491"
}
