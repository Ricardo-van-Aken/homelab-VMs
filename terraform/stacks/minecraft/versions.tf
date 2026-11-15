terraform {
  required_version = "1.13.9"

  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "1.70.2"
    }
    # Hetzner Object Storage speaks the S3 protocol; this provider makes
    # buckets on any server that does.
    minio = {
      source  = "aminueza/minio"
      version = "3.46.3"
    }
    sops = {
      source  = "carlpett/sops"
      version = "1.4.1"
    }
  }
}
