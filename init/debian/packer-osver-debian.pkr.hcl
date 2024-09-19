# OS variant oriented vars
# ----------
variable "variant" {
  type    = string
  default = "debian"
}

variable "osver" {
  type    = string
  ##default = "12"
  default = "5"
}

variable "vol_mgr" {
  type    = string
  default = "std"
}

variable "mirror_host_x64" {
  type    = string
  ##default = "mirror.math.princeton.edu/pub/debian-cd"
  default = "mirror.math.princeton.edu/pub/devuan"
}

variable "repo_host" {
  type    = string
  ##default = "deb.debian.org"
  default = "deb.devuan.org"
}

variable "repo_directory_x64" {
  type    = string
  ##default = "/debian"
  default = "/merged"
}

variable "iso_url_directory_x64" {
  type    = string
  ##default = "/current-live/amd64/iso-hybrid"
  ##default = "/current/amd64/iso-cd"
  #default = "/devuan_daedalus/minimal-live"
  default = "/devuan_daedalus/installer-iso"
}

variable "iso_base_x64" {
  type    = string
  ##default = "debian-live-12.7.0-amd64-standard"
  ##default = "debian-12.7.0-amd64-netinst"
  #default = "devuan_daedalus_5.0.0_amd64_minimal-live"
  default = "devuan_daedalus_5.0.1_amd64_netinstall"
}

variable "iso_cdlabel_x64" {
  type    = string
  default = "devuan_daedalus_5.0.0_amd64_minimal-live"
}

variable "mirror_host_aa64" {
  type    = string
  ##default = "mirror.math.princeton.edu/pub/debian-cd"
  default = "pkgmaster.devuan.org/devuan"
}

variable "repo_directory_aa64" {
  type    = string
  ##default = "/debian"
  default = "/merged"
}

variable "iso_url_directory_aa64" {
  type    = string
  ##default = "/current/arm64/iso-cd"
  default = "/dists/stable/main/installer-arm64/current/images"
}

variable "iso_base_aa64" {
  type    = string
  ##default = "debian-12.7.0-arm64-netinst"
  default = "netboot/mini"
}

variable "boot_cmdln_options" {
  type    = string
  default = " apparmor=0 "
}


# Builder common vars
# ----------
variable "author" {
  type    = string
  default = "thebridge0491"
}
