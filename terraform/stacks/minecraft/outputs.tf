output "backup_repository" {
  description = "Value for minecraft_backup_repository in ansible/inventory/group_vars/minecraft/main.yml."
  value       = "s3:https://${var.location}.your-objectstorage.com/${module.backups.name}"
}

# Shown with `tofu output -raw <name>`; the names contain the domain.
output "relay_name" {
  description = "Where players of the server at home connect, and Ansible reaches the relay."
  value       = var.relay_server ? "${local.relay_label}.${local.domain}" : null
  sensitive   = true
}

output "relay_address" {
  description = "Public IPv4 address of the relay."
  value       = var.relay_server ? hcloud_server.relay[0].ipv4_address : null
}

output "standby_name" {
  description = "Where players and Ansible reach the standby server."
  value       = var.standby_server ? "${local.standby_label}.${local.domain}" : null
  sensitive   = true
}

output "standby_address" {
  description = "Public IPv4 address of the standby server."
  value       = var.standby_server ? hcloud_server.standby[0].ipv4_address : null
}
