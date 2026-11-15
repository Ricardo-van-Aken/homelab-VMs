# Where every Minecraft server keeps its backups (minecraft_backup_repository
# in Ansible), and where a new one loads its world from.
module "backups" {
  source = "../../modules/backup-bucket"

  name = var.backup_bucket
}
