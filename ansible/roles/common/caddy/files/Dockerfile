# Caddy with a DNS provider plugin (caddy_dns_plugin), for the ACME DNS
# challenge. Built on the machine by compose (role caddy).
FROM caddy:2.11.9-builder-alpine@sha256:646fee578e680989ca5c7fd1ce6f1de574d19fd71ef2221810cc0510a9f40c86 AS builder

# Go module path with version, e.g. github.com/caddy-dns/hetzner/v2@v2.0.0.
ARG CADDY_DNS_PLUGIN
RUN xcaddy build --with "${CADDY_DNS_PLUGIN}"

FROM caddy:2.11.9-alpine@sha256:003a97808e781aa9f7e75cc2f43d34d461099031faf5e20faefb9f61126836f0

COPY --from=builder /usr/bin/caddy /usr/bin/caddy
