# Read for this run only; never written to the state.
ephemeral "sops_file" "credentials" {
  source_file = "${path.root}/../../secrets/credentials.sops.yaml"
}

# The domain and the home's public address, which Ansible reads too. All of
# this file ends up in the state, so it holds nothing else.
data "sops_file" "identity" {
  source_file = "${path.root}/../../../ansible/inventory/group_vars/all/identity.sops.yaml"
}

locals {
  domain       = data.sops_file.identity.data["homelab_domain"]
  home_address = data.sops_file.identity.data["homelab_public_address"]
}

provider "hcloud" {
  token = ephemeral.sops_file.credentials.data["hcloud_token"]
}
