# OS variant oriented vars
# ----------
variable "variant" {
  type    = string
  default = "openbsd"
}

variable "osver" {
  type    = string
  default = "7.5"
}

variable "vol_mgr" {
  type    = string
  default = "std"
}

variable "mirror_host_x64" {
  type    = string
  default = "cdn.openbsd.org/pub/OpenBSD"
}

variable "iso_url_directory_x64" {
  type    = string
  default = "/7.5"
}

variable "iso_base_x64" {
  type    = string
  default = "amd64/install75"
}

variable "mirror_host_aa64" {
  type    = string
  default = "cdn.openbsd.org/pub/OpenBSD"
}

variable "iso_url_directory_aa64" {
  type    = string
  default = "/7.5"
}

variable "iso_base_aa64" {
  type    = string
  default = "arm64/install75"
}

variable "boot_cmdln_options" {
  type    = string
  default = " "
}


# Builder common vars
# ----------
variable "author" {
  type    = string
  default = "thebridge0491"
}
