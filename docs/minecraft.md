# Minecraft

A Fabric server for Java players, which Bedrock players can join too
(Geyser and Floodgate), with the mods in
`ansible/roles/services/minecraft/defaults/main.yml`.

| Machine | Is |
|---|---|
| minecraft-server1 | the server, a VM at home on an isolated network of its own |
| minecraft-server1-egress | that VM's only way in and out: the home end of a WireGuard tunnel |
| minecraft-server1-relay | a rented server, the public end of the tunnel. Players connect to it, at `mc.<domain>`, so the home address shows up nowhere |
| minecraft-standby | the same server, rented, for when the one at home is down, at `minecraft-standby.<domain>` |

The two rented servers are made by the `minecraft` stack of
[cloud resources](cloud-resources.md), and may exist at the same time.
Every command at a glance: [cheatsheet](#cheatsheet).

## Settings

In `ansible/inventory/group_vars/minecraft/main.yml`:

* Read Mojang's [End User License Agreement (EULA)](https://aka.ms/MinecraftEULA)
  and set `minecraft_eula` to `true` to agree.
* Set `minecraft_seed` and `minecraft_world_radius`, the border a new world
  starts with. A seed only counts when a world is created: for another
  seed, give `minecraft_world` a new name.
* Structure settings shape the world as it is created. Save your
  `structurify.json` (and other mod settings) under
  `inventory/files/minecraft/` and list them in `minecraft_config_files`
  before the first run.
* For backups, set `minecraft_backup_repository` to the bucket,
  `s3:https://<endpoint>/<bucket>`, and `minecraft_backup_region` to its
  region. The OpenTofu stack makes one at Hetzner.

In `secrets.sops.yaml` beside it, put a key pair that may read and write
that bucket, and a long random `minecraft_backup_password`
([secrets](secrets.md)). Keep that password somewhere else too: without it
no backup can be read.

## The tunnel

Each end makes its own key pair and never gives away the private half.
The server at home is installed through the tunnel, so it is skipped
until the tunnel is up.

### With our own relay

Both ends are in this repository and read each other's public key. From
the repository's root, with the SOPS key unlocked ([secrets](secrets.md)):

1. In `terraform/stacks/minecraft/terraform.tfvars`, set
   `relay_server = true`, then rent the relay:

   ```sh
   tofu -chdir=terraform/stacks/minecraft apply
   ```

2. A relay made anew has a new SSH host key; forget the old one:

   ```sh
   ssh-keygen -R mc.<domain>
   ```

3. Set up the relay, the egress VM and the server:

   ```sh
   cd ansible
   ```

   ```sh
   ansible-playbook playbooks/site.yml --limit srv1,minecraft-server1-relay,minecraft-server1-egress,minecraft-server1
   ```

Players connect to `mc.<domain>`.

### With each end run by somebody else

Two people, each with a clone of this repository and an inventory of
their own. Only public keys are exchanged; the relay's operator does see
the home's public address, players never do.

First agree on the tunnel's addresses and ports, for example:

| Setting | Value |
|---|---|
| relay's address in the tunnel | `10.99.226.1/24` |
| home end's address in the tunnel | `10.99.226.2` |
| ports passed on to players | `25565` TCP (Java), `19132` UDP (Bedrock) |

**1. Home end: make a key.** In `host_vars/minecraft-server1-egress.yml`,
remove `egress_relay`, `egress_vpn_address` and `egress_vpn_endpoint`, and
run:

```sh
ansible-playbook playbooks/site.yml --limit srv1,minecraft-server1-egress
```

It shows the egress VM's public key. **Send it to the relay's operator.**

**2. Relay: set up.** Any Ubuntu server with a public address, in place
of minecraft-server1-relay in the `relay` group of `inventory/hosts.yml`,
with in its host_vars:

```yaml
relay_address: 10.99.226.1/24
relay_port: 51820
relay_peer_public_key: <public key from step 1>
relay_peer_address: 10.99.226.2
relay_forwards:
  - proto: tcp
    port: 25565  # Minecraft Java players
  - proto: udp
    port: 19132  # Minecraft Bedrock players
```

Its provider's firewall lets in `51820` UDP and the two ports from
everyone, and `22` TCP for whoever runs Ansible. Then:

```sh
ansible-playbook playbooks/site.yml --limit relay
```

It shows the relay's public key. **Send it to the home end's operator,
with the relay's public address or name and the port, `51820`.**

**3. Home end: connect.** In `host_vars/minecraft-server1-egress.yml`:

```yaml
egress_vpn_address: 10.99.226.2/32
egress_vpn_peer_public_key: <public key from step 2>
egress_vpn_endpoint: <relay's address or name>:51820
```

```sh
ansible-playbook playbooks/site.yml --limit srv1,minecraft-server1-egress,minecraft-server1
```

Players connect to the relay's address or name.

| Sent | From | To | Goes in |
|---|---|---|---|
| egress VM's public key | home end | relay | `relay_peer_public_key` |
| relay's public key | relay | home end | `egress_vpn_peer_public_key` |
| relay's address or name, and port | relay | home end | `egress_vpn_endpoint` |

## On the running server

Nobody gets in without being on the whitelist. That, and anything else on
the running server, is changed with commands, without Ansible. A player
who is an operator types them in the game with a `/` in front; otherwise:

```sh
ssh -J ubuntu@10.0.1.226 ubuntu@10.250.226.170 sudo docker exec minecraft rcon-cli "<command>"
```

| Command | Does |
|---|---|
| `whitelist add <name>` | lets a Java player in |
| `fwhitelist add <gamertag>` | lets a Bedrock player in |
| `whitelist remove <name>` | removes a player; Bedrock names start with a `.` |
| `op <name>` | lets a player run these commands in the game |
| `worldborder set <width>` | moves the border of the Overworld; the width is twice the distance from the middle |
| `execute in minecraft:the_nether run worldborder set <width>` | the same for the Nether; `minecraft:the_end` for the End |
| `chunky radius 1250`, then `chunky start` | creates the whole world up front, so nobody waits for it |

The mods' settings are files in `/srv/minecraft/data/config` on the VM;
restart the server after changing one:

```sh
ssh -J ubuntu@10.0.1.226 ubuntu@10.250.226.170 sudo docker restart minecraft
```

Bedrock clients update on their own. When they are refused after an
update, bump `geyser` in the role's mod list (see `AGENTS.md`, Dependency
pinning).

## Backups

The world and the server's settings are backed up to a Simple Storage
Service (S3) bucket every hour while somebody is playing. Backups are
encrypted before they leave the machine, and only what changed is
uploaded ([settings](#settings)).

On the server, this lists the backups:

```sh
sudo minecraft-restore
```

And this stops the server, puts the world back as it was in one of them
(`latest` for the newest), and starts it again:

```sh
sudo minecraft-restore <ID>
```

The world from before the restore is kept next to it until you delete it.
Add `with-settings` after the ID to bring back the whitelist, operators,
bans and the mods' settings as well. For a backup right now:

```sh
sudo docker exec minecraft-backup backup now
```

## The standby

minecraft-server1 and minecraft-standby back up to one bucket, and a
server that has no world yet loads the newest backup from it, whichever of
the two made it, with the whitelist and the mods' settings. Play on only
one of them at a time: each would carry on with its own copy of the world.

**When minecraft-server1 is down.** With `standby_server = true` applied
in the OpenTofu stack:

```sh
ansible-playbook playbooks/site.yml --limit minecraft-standby
```

A new server loads the newest backup, which is up to an hour old. A
standby you kept from last time still has its old world. Run
`sudo minecraft-restore latest with-settings` on it right after it starts:
an hour later it makes its first backup, and the old world would then be
the newest one.

**Going back home.** On the standby, take a last backup and stop the
server:

```sh
ssh root@minecraft-standby.<domain> docker exec minecraft-backup backup now
```

```sh
ssh root@minecraft-standby.<domain> docker compose --project-directory /opt/stacks/minecraft stop
```

Then, on minecraft-server1:

```sh
sudo minecraft-restore latest with-settings
```

The standby costs money while it exists, and one that is made anew always
starts from the newest backup. So set `standby_server = false` and apply
once you are back home.

## On another rented machine

The role also runs on any Ubuntu machine with 10 GB of memory or more,
without a tunnel:

* Add the machine to the `minecraft` group in `inventory/hosts.yml`, and
  only to that group.
* Give it a `host_vars/<name>.yml` with `ansible_host` and `ansible_user`,
  and `minecraft_data_device` if the worlds go on a disk of their own.
* In the provider's firewall, open `25565` TCP and `19132` UDP to everyone,
  and `22` TCP to your own address only. Nothing in this repository
  firewalls that machine.
* Run the playbook with `--limit <name>`.

## Cheatsheet

Commands on a server go after one of these:

| Server | Put in front |
|---|---|
| minecraft-server1 | `ssh -J ubuntu@10.0.1.226 ubuntu@10.250.226.170 sudo` |
| minecraft-standby | `ssh root@minecraft-standby.<domain>` |

| To | Command on the server |
|---|---|
| see who is online | `docker exec minecraft rcon-cli list` |
| run a game command ([list](#on-the-running-server)) | `docker exec minecraft rcon-cli "<command>"` |
| let a Java player in, by Java name | `docker exec minecraft rcon-cli "whitelist add <name>"` |
| let a Bedrock player in, by Xbox gamertag | `docker exec minecraft rcon-cli "fwhitelist add <gamertag>"` |
| follow the log | `docker logs -f --tail 100 minecraft` |
| restart | `docker restart minecraft` |
| stop, or `start` | `docker compose --project-directory /opt/stacks/minecraft stop` |
| back up now | `docker exec minecraft-backup backup now` |
| list the backups | `minecraft-restore` |
| load a backup, with whitelist and settings | `minecraft-restore <ID> with-settings` |

| To | Command on your machine |
|---|---|
| set up the server at home, its egress VM and the relay, from `ansible/` | `ansible-playbook playbooks/site.yml --limit srv1,minecraft-server1-relay,minecraft-server1-egress,minecraft-server1` |
| rent or remove the standby: set `standby_server` in `terraform.tfvars`, then | `tofu -chdir=terraform/stacks/minecraft apply` |
| set up the standby, from `ansible/`; a new one loads the newest backup | `ansible-playbook playbooks/site.yml --limit minecraft-standby` |

Moving play to the standby and back: [The standby](#the-standby).
