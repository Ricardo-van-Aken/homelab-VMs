# Caddy with a DNS provider plugin (caddy_dns_plugin), for the ACME DNS
# challenge. Built on the machine by compose (role caddy).
FROM caddy:2.11.8-builder-alpine@sha256:e42a64b3bc70aa3a1387bde85b930e507a378fecae5852d5bfde9dcd37d0b999 AS builder

# Go module path with version, e.g. github.com/caddy-dns/hetzner/v2@v2.0.0.
ARG CADDY_DNS_PLUGIN
RUN xcaddy build --with "${CADDY_DNS_PLUGIN}"

FROM caddy:2.11.9-alpine@sha256:0bbb055bda6793c999bde78b1b5ce3e89f829fb031af2cf50056ea1246559fee

COPY --from=builder /usr/bin/caddy /usr/bin/caddy
