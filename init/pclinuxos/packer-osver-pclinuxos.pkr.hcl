# OS variant oriented vars
# ----------
variable "variant" {
  type    = string
  default = "pclinuxos"
}

variable "osver" {
  type    = string
  default = "2022"
  #default = "2024"
}

variable "vol_mgr" {
  type    = string
  default = "std"
}

variable "mirror_host_x64" {
  type    = string
  default = "spout.ussg.indiana.edu/linux/pclinuxos"
}

variable "iso_url_directory_x64" {
  type    = string
  default = "/pclinuxos/iso"
}

variable "iso_base_x64" {
  type    = string
  default = "pclinuxos64-kde-darkstar-2022.11.30"
  #default = "pclinuxos64-kde-darkstar-2024.04"
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
  default = " nokmsboot noacpi nomodeset video=1024x768 keyb=us "
  #default = " "
}


# Builder common vars
# ----------
variable "author" {
  type    = string
  default = "thebridge0491"
}
