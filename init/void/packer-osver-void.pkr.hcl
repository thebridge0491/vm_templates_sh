# OS variant oriented vars
# ----------
variable "variant" {
  type    = string
  default = "void"
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
  default = "repo-default.voidlinux.org"
}

variable "iso_url_directory_x64" {
  type    = string
  default = "/live/current"
}

variable "iso_base_x64" {
  type    = string
  #default = "void-live-x86_64-20240314-base"
  #default = "void-hrmpf-x86_64-6.5.12_1-20231124"
  default = "void-mklive-x86_64-6.0.13_1-20221218"
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
