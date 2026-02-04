# OS variant oriented vars
# ----------
variable "variant" {
  type    = string
  default = "void"
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
  #default = "void-live-x86_64-20250202-base"
  #default = "void-mklive-x86_64-6.0.13_1-20221218"
  default = "void-hrmpf-x86_64-20250228"
}

variable "mirror_host_aa64" {
  type    = string
  default = "repo-default.voidlinux.org"
}

variable "iso_url_directory_aa64" {
  type    = string
  default = "/live/current"
}

variable "iso_base_aa64" {
  type    = string
  #default = "void-live-aarch64-20250202-base"
  #default = null
  default = "void-hrmpf-aarch64-20250228"
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
