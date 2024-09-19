# OS variant oriented vars
# ----------
variable "variant" {
  type    = string
  default = "alpine"
}

variable "osver" {
  type    = string
  default = "v3.20"
}

variable "vol_mgr" {
  type    = string
  default = "std"
}

variable "mirror_host_x64" {
  type    = string
  default = "dl-cdn.alpinelinux.org/alpine"
}

variable "iso_url_directory_x64" {
  type    = string
  default = "/latest-stable/releases/x86_64"
}

variable "iso_base_x64" {
  type    = string
  default = "alpine-extended-3.20.3-x86_64"
}

variable "mirror_host_aa64" {
  type    = string
  default = "dl-cdn.alpinelinux.org/alpine"
}

variable "iso_url_directory_aa64" {
  type    = string
  default = "/latest-stable/releases/aarch64"
}

variable "iso_base_aa64" {
  type    = string
  default = "alpine-standard-3.20.3-aarch64"
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
