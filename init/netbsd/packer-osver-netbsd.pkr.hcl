# OS variant oriented vars
# ----------
variable "variant" {
  type    = string
  default = "netbsd"
}

variable "osver" {
  type    = string
  default = "10.0"
}

variable "vol_mgr" {
  type    = string
  default = "std"
}

variable "mirror_host_x64" {
  type    = string
  default = "cdn.netbsd.org/pub/NetBSD"
}

variable "iso_url_directory_x64" {
  type    = string
  default = "/images/10.0"
}

variable "iso_base_x64" {
  type    = string
  default = "NetBSD-10.0-amd64"
}

variable "mirror_host_aa64" {
  type    = string
  default = "cdn.netbsd.org/pub/NetBSD"
}

variable "iso_url_directory_aa64" {
  type    = string
  default = "/images/10.0"
}

variable "iso_base_aa64" {
  type    = string
  default = "NetBSD-10.0-evbarm-aarch64"
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
