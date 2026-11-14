# The domain's DNS zone at Hetzner, and the records in it that are kept by
# hand. Records another stack owns (a server's name) are in that stack.

# The zone exists already: Caddy proves the domain to Let's Encrypt through
# it. It is imported, not created. Records that are not in any stack,
# Caddy's _acme-challenge ones among them, are left alone.
import {
  to = hcloud_zone.main
  id = local.domain
}

resource "hcloud_zone" "main" {
  name = local.domain
  mode = "primary"

  # Destroying the zone would take every name and certificate with it.
  delete_protection = true

  lifecycle {
    prevent_destroy = true
  }
}

# The name VPN clients connect to (wireguard_public_host in Ansible). It
# exists already as well.
import {
  to = hcloud_zone_rrset.vpn
  id = "${local.domain}/wg-easy/A"
}

resource "hcloud_zone_rrset" "vpn" {
  zone = hcloud_zone.main.name
  name = "wg-easy"
  type = "A"

  records = [
    { value = local.home_address },
  ]
}
