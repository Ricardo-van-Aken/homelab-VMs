# Minecraft

A Fabric server for Java players, which Bedrock players can join too
(Geyser and Floodgate), with the mods in
`ansible/roles/services/minecraft/defaults/main.yml`.

| Machine | Is |
|---|---|
| minecraft-server1 | the server, a VM at home on an isolated network of its own |
| minecraft-server1-egress | that VM's only way in and out: the home end of a WireGuard tunnel, and of a second way in over NetBird |
| minecraft-server1-relay | a rented server, the public end of the tunnel. Players connect to it, at `ddg-craft.<domain>`, so the home address shows up nowhere |
| minecraft-server1-standby | the same server, rented, for when the one at home is down, at `ddg-craft-standby.<domain>` |

The two rented servers are made by the `minecraft` stack of
[cloud resources](cloud-resources.md), and may exist at the same time.
Every command at a glance: [cheatsheet](#cheatsheet).

A map of the world (BlueMap) is at `https://map.ddg-craft.<domain>`
(the relay's `relay_sites`), for anyone who knows the address, without a
login.

## Settings

In `ansible/inventory/group_vars/minecraft/main.yml`:

* Read Mojang's [End User License Agreement (EULA)](https://aka.ms/MinecraftEULA)
  and set `minecraft_eula` to `true` to agree.
* Set `minecraft_seed` and `minecraft_world_radius`, the border a new world
  starts with; `minecraft_dimension_radius` gives the Nether or the End
  another one. A seed only counts when a world is created: for another
  seed, give `minecraft_world` a new name.
* Structure settings shape the world as it is created. Save your
  `structurify.json` (and other mod settings) under
  `inventory/files/minecraft/` and list them in `minecraft_config_files`.
  A new world is created with them; once it exists, the files on the
  server are kept.
* Save datapacks as zip files under `inventory/files/minecraft/datapacks/`
  and list them in `minecraft_datapacks`. The server loads them at every
  start, and drops one that is no longer listed.
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
   ssh-keygen -R ddg-craft.<domain>
   ```

3. Set up the relay, the egress VM and the server:

   ```sh
   cd ansible
   ```

   ```sh
   ansible-playbook playbooks/site.yml --limit srv1,minecraft-server1-relay,minecraft-server1-egress,minecraft-server1
   ```

Players connect to `ddg-craft.<domain>`.

### With each end run by somebody else

Two people, each with a clone of this repository and an inventory of
their own. Only public keys are exchanged; the relay's operator does see
the home's public address, players never do.

First agree on the tunnel's addresses and ports, for example:

| Setting | Value |
|---|---|
| relay's address in the tunnel | `10.99.226.1/24` |
| home end's address in the tunnel | `10.99.226.2` |
| ports passed on to players | `25565` TCP (Java), `19132` TCP and UDP (Bedrock) |
| the map's name | points at the relay, which serves it over HTTPS |

**1. Home end: make a key.** In `host_vars/minecraft-server1-egress/main.yml`,
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
  - proto: tcp
    port: 19132  # Minecraft Bedrock players, joining (NetherNet)
  - proto: udp
    port: 19132  # Minecraft Bedrock players
relay_sites:
  - <the map's name>
```

Its provider's firewall lets in `51820` UDP, the two game ports, and `80`
and `443` TCP from everyone, and `22` TCP for whoever runs Ansible. The
map's name points at this server, which serves it over HTTPS and asks the
home end for it. Then:

```sh
ansible-playbook playbooks/site.yml --limit relay
```

It shows the relay's public key. **Send it to the home end's operator,
with the relay's public address or name and the port, `51820`.**

**3. Home end: connect.** In `host_vars/minecraft-server1-egress/main.yml`:

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

### A second way in, over NetBird

Somebody else's NetBird network, in which a public server of theirs passes
the game ports to the egress VM. Players use that server's address. Each
way in works without the other.

1. Ask the operator for the management server's address and a setup key,
   and write them as `egress_netbird_management_url` and
   `egress_netbird_setup_key` ([secrets](secrets.md)):

   ```sh
   sops edit ansible/inventory/host_vars/minecraft-server1-egress/secrets.sops.yaml
   ```

2. Set up the egress VM, from `ansible/`:

   ```sh
   ansible-playbook playbooks/site.yml --limit minecraft-server1-egress
   ```

3. Read the egress VM's address in the network, and send it to the
   operator:

   ```sh
   ssh ubuntu@10.0.1.226 sudo netbird status
   ```

4. The operator's server passes `25565` TCP and `19132` TCP and UDP to that
   address, and masquerades them, so the replies return to it.

5. For the map, the operator's server serves a name of their choice over
   HTTPS and passes the requests to port `80` of that address. Any name
   works, and nothing here changes when it does.

In `host_vars/minecraft-server1-egress/main.yml`:

| Setting | `false` means |
|---|---|
| `egress_vpn` | no tunnel to our relay; NetBird is the only way in |
| `egress_netbird` | no NetBird; it is removed from the egress VM |
| `egress_outbound_lan` | the server has no way out while the relay is gone, so Java logins fail |

With `egress_outbound_lan`, the server reaches Mojang through the home
connection while the relay is off or silent. The operator of the NetBird
network sees the home's public address; players never do.

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
| `chunky radius 2500`, then `chunky start` | creates the Overworld up front, so nobody waits for it |
| `gamerule players_sleeping_percentage 66` | how many of the players have to sleep to skip the night, in percent |
| `ledger inspect` | hit a block to see who changed it; `ledger rollback` undoes changes |
| `spark profiler start`, then `spark profiler stop` | measures where the server's time goes, and gives a link to the result |

The mods' settings are files in `/srv/minecraft/data/config` on the VM;
restart the server after changing one:

```sh
ssh -J ubuntu@10.0.1.226 ubuntu@10.250.226.170 sudo docker restart minecraft
```

Bedrock clients update on their own. When they are refused after an
update, bump `geyser` in the role's mod list (see `AGENTS.md`, Dependency
pinning).

Java players on a newer Minecraft than the server's get in through
ViaVersion. After a new Minecraft release they are refused until
`viafabric` is bumped in the same list.

## Backups

The world and the server's settings are backed up to a Simple Storage
Service (S3) bucket every 15 minutes while somebody is playing
(`minecraft_backup_interval`). The bucket shows no file per backup: each
one is stored as the pieces that changed, and restic lists them. Backups are
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

minecraft-server1 and minecraft-server1-standby back up to one bucket, and a
server that has no world yet loads the newest backup from it, whichever of
the two made it, with the whitelist and the mods' settings. Play on only
one of them at a time: each would carry on with its own copy of the world.

### Set up a new standby

From the repository's root, with the SOPS key unlocked
([secrets](secrets.md)):

1. If minecraft-server1 still runs, take a last backup there and stop it:

   ```sh
   ssh -J ubuntu@10.0.1.226 ubuntu@10.250.226.170 sudo docker exec minecraft-backup backup now
   ```

   ```sh
   ssh -J ubuntu@10.0.1.226 ubuntu@10.250.226.170 sudo docker compose --project-directory /opt/stacks/minecraft stop
   ```

2. In `terraform/stacks/minecraft/terraform.tfvars`, set
   `standby_server = true`, then rent the server:

   ```sh
   tofu -chdir=terraform/stacks/minecraft apply
   ```

3. A server made anew has a new SSH host key; forget the old one:

   ```sh
   ssh-keygen -R ddg-craft-standby.<domain>
   ```

4. Set it up, from `ansible/`. It loads the newest backup, which is up to
   15 minutes old:

   ```sh
   ansible-playbook playbooks/site.yml --limit minecraft-server1-standby
   ```

   Or, for a new world with an empty whitelist instead of the backup:

   ```sh
   ansible-playbook playbooks/site.yml --limit minecraft-server1-standby -e minecraft_backup_load_new_server=false
   ```

Players connect to `ddg-craft-standby.<domain>`; the map is at
`https://ddg-craft-standby.<domain>` and is drawn anew.

A standby you kept from last time still has its old world. Run
`minecraft-restore latest with-settings` on it right after it starts:
15 minutes later it makes its first backup, and the old world would then
be the newest one.

### Going back home

On the standby, take a last backup and stop the server:

```sh
ssh root@ddg-craft-standby.<domain> docker exec minecraft-backup backup now
```

```sh
ssh root@ddg-craft-standby.<domain> docker compose --project-directory /opt/stacks/minecraft stop
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
* In the provider's firewall, open `25565` TCP, `19132` TCP and UDP, and `80` and
  `443` TCP (the map) to everyone, and `22` TCP to your own address only.
  Nothing in this repository firewalls that machine.
* For the map, set `minecraft_map_domain` to a name that points at the
  machine.
* Run the playbook with `--limit <name>`.

## Cheatsheet

Commands on a server go after one of these:

| Server | Put in front |
|---|---|
| minecraft-server1 | `ssh -J ubuntu@10.0.1.226 ubuntu@10.250.226.170 sudo` |
| minecraft-server1-standby | `ssh root@ddg-craft-standby.<domain>` |

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
| set up the standby, from `ansible/`; a new one loads the newest backup | `ansible-playbook playbooks/site.yml --limit minecraft-server1-standby` |

Moving play to the standby and back: [The standby](#the-standby).
