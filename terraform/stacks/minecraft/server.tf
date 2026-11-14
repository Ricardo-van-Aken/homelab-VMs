# A Minecraft server outside the house, for when the one at home is down.
# Ansible (group minecraft) installs it; it loads the world from the bucket.

# A public key can be at Hetzner only once: a later stack looks these up
# (data "hcloud_ssh_keys") instead of uploading them again.
resource "hcloud_ssh_key" "admin" {
  for_each = var.ssh_public_keys

  name       = each.key
  public_key = each.value
}

# Hetzner's firewall, in front of the server. Docker publishes the game
# ports past any firewall on the server itself, so this is the one that
# counts.
resource "hcloud_firewall" "standby" {
  name = var.standby_name

  rule {
    description = "SSH, for you and Ansible, from home only"
    direction   = "in"
    protocol    = "tcp"
    port        = "22"
    source_ips  = ["${data.sops_file.home.data["address"]}/32"]
  }

  rule {
    description = "ping"
    direction   = "in"
    protocol    = "icmp"
    source_ips  = ["0.0.0.0/0", "::/0"]
  }

  rule {
    description = "Minecraft, Java players"
    direction   = "in"
    protocol    = "tcp"
    port        = "25565"
    source_ips  = ["0.0.0.0/0", "::/0"]
  }

  rule {
    description = "Minecraft, Bedrock players (Geyser)"
    direction   = "in"
    protocol    = "udp"
    port        = "19132"
    source_ips  = ["0.0.0.0/0", "::/0"]
  }
}

resource "hcloud_server" "standby" {
  count = var.standby_server ? 1 : 0

  name         = var.standby_name
  server_type  = var.standby_server_type
  image        = var.standby_image
  location     = var.location
  ssh_keys     = [for key in hcloud_ssh_key.admin : key.id]
  firewall_ids = [hcloud_firewall.standby.id]

  # A new key or image is for the next server; it does not rebuild this one.
  lifecycle {
    ignore_changes = [ssh_keys, image]
  }
}

# The zone is the dns stack's; only this one record in it is made here.
data "hcloud_zone" "main" {
  name = local.domain
}

resource "hcloud_zone_rrset" "standby" {
  count = var.standby_server ? 1 : 0

  zone = data.hcloud_zone.main.name
  name = var.standby_name
  type = "A"
  # Short, so players follow quickly when the server is made anew.
  ttl = 300

  records = [
    { value = hcloud_server.standby[0].ipv4_address },
  ]
}
