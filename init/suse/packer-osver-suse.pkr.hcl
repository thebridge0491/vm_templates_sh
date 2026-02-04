# OS variant oriented vars
# ----------
variable "variant" {
  type    = string
  default = "suse"
}

variable "vol_mgr" {
  type    = string
  default = "std"
}

variable "mirror_host_x64" {
  type    = string
  default = "download.opensuse.org"
}

variable "repo_directory" {
  type    = string
  default = "/distribution/openSUSE-current/repo/oss"
}

variable "iso_url_directory_x64" {
  type    = string
  ##default = "/distribution/openSUSE-current/iso"
  ##default = "/distribution/openSUSE-current/live"
  #default = "/slowroll/iso"
  default = "/tumbleweed/iso"
}

variable "iso_base_x64" {
  type    = string
  ##default = "openSUSE-Leap-15.6-NET-x86_64-Media"
  ##default = "live/openSUSE-Leap-15.6-XFCE-Live-x86_64-Media"
  #default = "openSUSE-Slowroll-NET-x86_64-Media"
  default = "openSUSE-Tumbleweed-XFCE-Live-x86_64-Media"
}

variable "iso_cdlabel_x64" {
  type    = string
  ##default = "openSUSE_Leap_15.6_XFCE_Live"
  ##default = "openSUSE-Leap-15.6-NET-x86_64710"
  default = "openSUSE_Tumbleweed_XFCE_Live"
  #default = "openSUSE-Slowroll-NET-x86_64"
  #default = "openSUSE-Tumbleweed-NET-x86_64"
}

variable "mirror_host_aa64" {
  type    = string
  default = "download.opensuse.org"
}

variable "iso_url_directory_aa64" {
  type    = string
  #default = "/distribution/openSUSE-current/iso"
  default = "/download/ports/aarch64/tumbleweed/iso"
}

variable "iso_base_aa64" {
  type    = string
  ##default = "openSUSE-Leap-15.6-NET-aarch64-Media"
  ##default = "live/openSUSE-Leap-15.6-XFCE-Live-aarch64-Media"
  #default = "openSUSE-Tumbleweed-NET-aarch64-Media"
  default = "openSUSE-Tumbleweed-XFCE-Live-aarch64-Media"
}

variable "iso_cdlabel_aa64" {
  type    = string
  ##default = "openSUSE_Leap_15.6_XFCE_Live"
  ##default = "openSUSE-Leap-15.6-NET-aarch6471"
  default = "openSUSE_Tumbleweed_XFCE_Live"
  #default = "openSUSE-Tumbleweed-NET-aarch64"
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
