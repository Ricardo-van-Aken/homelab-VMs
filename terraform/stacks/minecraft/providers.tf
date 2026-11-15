# Read for this run only; never written to the state.
ephemeral "sops_file" "credentials" {
  source_file = "${path.root}/../../secrets/credentials.sops.yaml"
}

# The bucket's S3 credentials, which the Minecraft servers back up with.
# Ansible's file is the only place they are kept.
ephemeral "sops_file" "minecraft" {
  source_file = "${path.root}/../../../ansible/inventory/group_vars/minecraft/secrets.sops.yaml"
}

# The domain, the home's public address and the SSH keys, which Ansible
# reads too. All of this file ends up in the state, so it holds nothing else.
data "sops_file" "identity" {
  source_file = "${path.root}/../../../ansible/inventory/group_vars/all/identity.sops.yaml"
}

locals {
  domain              = data.sops_file.identity.data["homelab_domain"]
  home_address        = data.sops_file.identity.data["homelab_public_address"]
  ssh_keys_authorized = yamldecode(data.sops_file.identity.raw).ssh_keys_authorized
}

provider "hcloud" {
  token = ephemeral.sops_file.credentials.data["hcloud_token"]
}

provider "minio" {
  minio_server   = "${var.location}.your-objectstorage.com"
  minio_region   = var.location
  minio_user     = ephemeral.sops_file.minecraft.data["minecraft_backup_access_key_id"]
  minio_password = ephemeral.sops_file.minecraft.data["minecraft_backup_secret_access_key"]
  minio_ssl      = true
}
