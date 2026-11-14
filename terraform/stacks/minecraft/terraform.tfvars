# Settings; nothing secret. The secrets are in ../../secrets, encrypted.

location      = "fsn1"
backup_bucket = "minecraft-backups-24de02e1"

standby_server = true

# The same keys as ssh_keys_authorized in ansible/inventory/group_vars/all.yml.
ssh_public_keys = {
  homelab = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAmSIvhk/L829v6onj9pQRYkas44rx8GAtt+b+UGdL3y homelab"
  macbook = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDEb07SmW4aQhUAC9ZKYBtaQ4XDnwDn03+mPR7cGmjJK macbook"
  desktop = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIP8fbzNpDy0ZkUiuOn899MIsR7cFVhOk6aG3ocdWx3YT desktop"
}
