# Settings; nothing secret. The secrets are encrypted *.sops.yaml files, and
# what Ansible needs as well is in ansible/inventory/group_vars.

location      = "fsn1"
backup_bucket = "minecraft-backups-24de02e1"

# Which of the two servers exist. The relay is needed while the server at
# home is in use; the standby only while it is down.
relay_server   = false
standby_server = false
