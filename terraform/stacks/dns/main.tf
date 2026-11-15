# The domain's DNS zone at Hetzner, and the records in it that are kept by
# hand. Records another stack owns (a server's name) are in that stack.

# The zone existed before this stack and was imported. Records that are not
# in any stack, Caddy's _acme-challenge ones among them, are left alone.
resource "hcloud_zone" "main" {
  name = local.domain
  mode = "primary"
  # Seconds a record without its own value is remembered; as it was.
  ttl = 7200

  # Destroying the zone would take every name and certificate with it.
  delete_protection = true

  lifecycle {
    prevent_destroy = true
  }
}

# The name VPN clients connect to (wireguard_public_host in Ansible).
resource "hcloud_zone_rrset" "vpn" {
  zone = hcloud_zone.main.name
  name = "wg-easy"
  type = "A"
  ttl  = 3600

  records = [
    { value = local.home_address },
  ]
}
