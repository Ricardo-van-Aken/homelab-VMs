# Secrets

Every secret is in a file ending in `.sops.yaml` or `.sops.json`, encrypted
with [SOPS](https://github.com/getsops/sops). Ansible decrypts them on its
own, and OpenTofu ([cloud resources](cloud-resources.md)) reads the same
files. The ones in the repository are encrypted for my key: you cannot read
them, so delete them and make your own.

## Make a key

Install SOPS and [age](https://github.com/FiloSottile/age), then make a
key, protected with a passphrase you choose:

```sh
mkdir -p ~/.config/sops/age
```

```sh
age-keygen | age -p -o ~/.config/sops/age/key.age
```

It prints the key's public half. Put that in `.sops.yaml` in the
repository's root.

In every terminal you work in, unlock the key once. It asks for the
passphrase and keeps the key in memory only:

```sh
export SOPS_AGE_KEY=$(age -d ~/.config/sops/age/key.age | grep AGE-SECRET-KEY)
```

A run that says it failed to get the data key means the key is not
unlocked in that terminal.

## Write the files

The command opens an editor and encrypts on saving. Replace what it shows
with the names below and your values:

```sh
sops edit ansible/inventory/group_vars/all/identity.sops.yaml
```

The `main.yml` next to each file says what every value is, under a
`# SECRET:` line.

| File, under `ansible/inventory/` | Holds |
|---|---|
| `group_vars/all/identity.sops.yaml` | `homelab_domain`, `homelab_public_address`. Nothing else, and nowhere else: they say whose homelab this is |
| `group_vars/all/secrets.sops.yaml` | `caddy_acme_email`, `caddy_dns_token` |
| `group_vars/pihole/secrets.sops.yaml` | `pihole_web_password` |
| `group_vars/wireguard/secrets.sops.yaml` | `wireguard_admin_password` |
| `group_vars/forgejo/secrets.sops.yaml` | `forgejo_admin_email`, `forgejo_admin_password`, `forgejo_users` |
| `group_vars/jellyfin/secrets.sops.yaml` | `jellyfin_admin_password`, `jellyfin_users` |
| `group_vars/samba/secrets.sops.yaml` | `samba_password` |
| `group_vars/mealie/secrets.sops.yaml` | `mealie_proxy_secret`, `mealie_admin_password` |
| `group_vars/minecraft/secrets.sops.yaml` | `minecraft_backup_access_key_id`, `minecraft_backup_secret_access_key`, `minecraft_backup_password` |
| `host_vars/torrent-egress/secrets.sops.yaml` | `egress_vpn_private_key`, when the VPN provider made the key pair |
| `host_vars/minecraft-server1-egress/secrets.sops.yaml` | `egress_netbird_management_url`, `egress_netbird_setup_key`, from the NetBird network's operator |

Only OpenTofu needs `terraform/secrets/credentials.sops.yaml`; the
`.example.yaml` beside it shows what goes in.
