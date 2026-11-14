variable "location" {
  description = "Hetzner location of the server and the bucket: fsn1, nbg1 or hel1."
  type        = string
  default     = "fsn1"
}

variable "backup_bucket" {
  description = "Name of the bucket for the Minecraft backups."
  type        = string
}

variable "standby_server" {
  description = "Whether the standby Minecraft server exists. false removes the server and its DNS record, and stops its cost; the bucket stays."
  type        = bool
  default     = true
}

variable "standby_name" {
  description = "Name of the standby server, also its name under the domain and in the Ansible inventory."
  type        = string
  default     = "minecraft-standby"
}

variable "standby_server_type" {
  description = "Hetzner server type. The Minecraft role wants 6 GB of memory or more."
  type        = string
  default     = "cx33"
}

variable "standby_image" {
  description = "Operating system image; the Ansible roles are written for Ubuntu."
  type        = string
  default     = "ubuntu-26.04"
}

variable "ssh_public_keys" {
  description = "Public keys that may log in as root on a new server, by a name of your choice. Ansible (role ssh_keys) adds the rest later."
  type        = map(string)

  validation {
    condition     = length(var.ssh_public_keys) > 0
    error_message = "Give at least one key, or nobody can log in to the server."
  }
}
