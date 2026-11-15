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
  description = "Name of the standby server: its name in the Ansible inventory, whose host_vars say what it is called under the domain."
  type        = string
  default     = "minecraft-server1-standby"
}

variable "standby_server_type" {
  description = "Hetzner server type. 8 GB of memory: the standby gives the game less than the server at home (host_vars/minecraft-server1-standby.yml)."
  type        = string
  default     = "cx33"
}

variable "relay_server" {
  description = "Whether the relay exists: the public end of the tunnel to the Minecraft server at home, which players connect to. false removes the server and its DNS record."
  type        = bool
  default     = true
}

variable "relay_name" {
  description = "Name of the relay: its name in the Ansible inventory, whose host_vars say what it is called under the domain, which port the tunnel uses and which machine at home is the other end."
  type        = string
  default     = "minecraft-server1-relay"
}

variable "relay_server_type" {
  description = "Hetzner server type of the relay. It only passes packets on, so the smallest does."
  type        = string
  default     = "cx23"
}

variable "image" {
  description = "Operating system image of the servers; the Ansible roles are written for Ubuntu."
  type        = string
  default     = "ubuntu-26.04"
}
