# Read for this run only; never written to the state.
ephemeral "sops_file" "credentials" {
  source_file = "${path.root}/../../secrets/credentials.sops.yaml"
}

# The domain and the home address. They end up in the state, as part of
# the record and the firewall rule they are used in.
data "sops_file" "home" {
  source_file = "${path.root}/../../secrets/home.sops.yaml"
}

locals {
  domain = data.sops_file.home.data["domain"]
}

provider "hcloud" {
  token = ephemeral.sops_file.credentials.data["hcloud_token"]
}

provider "minio" {
  minio_server   = "${var.location}.your-objectstorage.com"
  minio_region   = var.location
  minio_user     = ephemeral.sops_file.credentials.data["s3_access_key"]
  minio_password = ephemeral.sops_file.credentials.data["s3_secret_key"]
  minio_ssl      = true
}
