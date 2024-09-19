# OS variant oriented vars
# ----------
variable "variant" {
  type    = string
  default = "freebsd"
}

variable "osver" {
  type    = string
  default = "13.3"
}

variable "vol_mgr" {
  type    = string
  default = "std"
}

variable "mirror_host_x64" {
  type    = string
  default = "download.freebsd.org/ftp"
}

variable "iso_url_directory_x64" {
  type    = string
  default = "/releases/ISO-IMAGES/13.3"
}

variable "iso_base_x64" {
  type    = string
  default = "FreeBSD-13.3-RELEASE-amd64"
}

variable "mirror_host_aa64" {
  type    = string
  default = "download.freebsd.org/ftp"
}

variable "iso_url_directory_aa64" {
  type    = string
  default = "/releases/ISO-IMAGES/13.3"
}

variable "iso_base_aa64" {
  type    = string
  default = "FreeBSD-13.3-RELEASE-arm64-aarch64"
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
