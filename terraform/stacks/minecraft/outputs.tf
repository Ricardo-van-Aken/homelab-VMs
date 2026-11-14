output "backup_repository" {
  description = "Value for minecraft_backup_repository in ansible/inventory/group_vars/minecraft.yml."
  value       = "s3:https://${var.location}.your-objectstorage.com/${module.backups.name}"
}

# Shown with `terraform output -raw standby_name`; it contains the domain.
output "standby_name" {
  description = "Where players and Ansible reach the standby server."
  value       = var.standby_server ? "${var.standby_name}.${local.domain}" : null
  sensitive   = true
}

output "standby_address" {
  description = "Public IPv4 address of the standby server."
  value       = var.standby_server ? hcloud_server.standby[0].ipv4_address : null
}
