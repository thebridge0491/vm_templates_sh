# OS variant oriented vars
# ----------
variable "variant" {
  type    = string
  default = "suse"
}

variable "osver" {
  type    = string
  default = "15.5"
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
  #default = "/distribution/openSUSE-current/iso"
  default = "/distribution/openSUSE-current/live"
}

variable "iso_base_x64" {
  type    = string
  ##default = "GeckoLinux_STATIC_BareBones.x86_64-154.220822.0"
  #default = "openSUSE-Leap-15.5-NET-x86_64-Media"
  default = "openSUSE-Leap-15.5-XFCE-Live-x86_64-Media"
}

variable "iso_cdlabel_x64" {
  type    = string
  #default = "GeckoLinux_STATIC_BareBones"
  default = "openSUSE_Leap_15.5_XFCE_Live"
}

variable "mirror_host_aa64" {
  type    = string
  default = "download.opensuse.org"
}

variable "iso_url_directory_aa64" {
  type    = string
  default = "/distribution/openSUSE-current/iso"
}

variable "iso_base_aa64" {
  type    = string
  #default = "openSUSE-Leap-15.5-NET-aarch64-Media"
  default = "openSUSE-Leap-15.5-XFCE-Live-aarch64-Media"
}

variable "iso_cdlabel_aa64" {
  type    = string
  default = "openSUSE_Leap_15.5_XFCE_Live"
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
