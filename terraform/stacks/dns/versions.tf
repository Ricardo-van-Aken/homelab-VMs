terraform {
  required_version = "1.13.9"

  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "1.70.2"
    }
    sops = {
      source  = "carlpett/sops"
      version = "1.4.1"
    }
  }
}
