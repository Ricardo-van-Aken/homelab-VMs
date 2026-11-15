# The public end of the tunnel to the Minecraft server at home. Players
# connect to it, and Ansible (group relay) makes it pass them down the
# tunnel, so the home address shows up nowhere.

# What Ansible knows about the relay: its name under the domain, the
# tunnel's port and the ports passed on. Read from its inventory, so the
# firewall here cannot differ from the one there. The ports are the relay's
# own relay_forwards, or else those of the home end it names (relay_egress).
locals {
  relay_vars  = yamldecode(file("${path.root}/../../../ansible/inventory/host_vars/${var.relay_name}.yml"))
  relay_label = trimsuffix(local.relay_vars.ansible_host, ".{{ homelab_domain }}")
  # The home end's file, or its main.yml when it has a directory.
  egress_vars = try(
    yamldecode(file("${path.root}/../../../ansible/inventory/host_vars/${local.relay_vars.relay_egress}/main.yml")),
    yamldecode(file("${path.root}/../../../ansible/inventory/host_vars/${local.relay_vars.relay_egress}.yml")),
    {},
  )
  relay_ports = try(local.relay_vars.relay_forwards, local.egress_vars.egress_inbound, [])
  # With web sites of its own (relay_sites), the relay serves these itself.
  relay_web = length(try(local.relay_vars.relay_sites, [])) > 0 ? [80, 443] : []
  # Other names under the domain that point at the relay.
  relay_aliases = try(local.relay_vars.relay_aliases, [])
}

resource "hcloud_firewall" "relay" {
  name = var.relay_name

  rule {
    description = "SSH, for you and Ansible, from home only"
    direction   = "in"
    protocol    = "tcp"
    port        = "22"
    source_ips  = ["${local.home_address}/32"]
  }

  rule {
    description = "ping"
    direction   = "in"
    protocol    = "icmp"
    source_ips  = ["0.0.0.0/0", "::/0"]
  }

  # From anywhere: the home address is not fixed, and only the holder of
  # the home end's key gets an answer.
  rule {
    description = "the tunnel, from the home end"
    direction   = "in"
    protocol    = "udp"
    port        = tostring(local.relay_vars.relay_port)
    source_ips  = ["0.0.0.0/0", "::/0"]
  }

  dynamic "rule" {
    for_each = local.relay_ports

    content {
      description = "passed down the tunnel"
      direction   = "in"
      protocol    = rule.value.proto
      port        = tostring(rule.value.port)
      source_ips  = ["0.0.0.0/0", "::/0"]
    }
  }

  dynamic "rule" {
    for_each = local.relay_web

    content {
      description = "web sites the relay serves, and Let's Encrypt"
      direction   = "in"
      protocol    = "tcp"
      port        = tostring(rule.value)
      source_ips  = ["0.0.0.0/0", "::/0"]
    }
  }

  lifecycle {
    precondition {
      condition     = !strcontains(local.relay_label, "{{") && !strcontains(local.relay_label, ".")
      error_message = "ansible_host of the relay must be \"<name>.{{ homelab_domain }}\": that name becomes its DNS record."
    }
  }
}

resource "hcloud_server" "relay" {
  count = var.relay_server ? 1 : 0

  name         = var.relay_name
  server_type  = var.relay_server_type
  image        = var.image
  location     = var.location
  ssh_keys     = [for key in hcloud_ssh_key.admin : key.id]
  firewall_ids = [hcloud_firewall.relay.id]

  # A new key or image is for the next server; it does not rebuild this one.
  lifecycle {
    ignore_changes = [ssh_keys, image]
  }
}

resource "hcloud_zone_rrset" "relay" {
  count = var.relay_server ? 1 : 0

  zone = data.hcloud_zone.main.name
  name = local.relay_label
  type = "A"
  # Short, so players and the home end follow quickly when the server is
  # made anew.
  ttl = 300

  records = [
    { value = hcloud_server.relay[0].ipv4_address },
  ]
}

resource "hcloud_zone_rrset" "relay_alias" {
  for_each = toset(var.relay_server ? local.relay_aliases : [])

  zone = data.hcloud_zone.main.name
  name = each.value
  type = "A"
  ttl  = 300

  records = [
    { value = hcloud_server.relay[0].ipv4_address },
  ]
}
