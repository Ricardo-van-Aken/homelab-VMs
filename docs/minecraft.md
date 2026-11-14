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

## The tunnel

Each end makes its own key pair and never gives away the private half.
With both ends in this repository, as they are, they read each other's
public key, so there is nothing to copy. Apply the Terraform stack, then
from `ansible/`:

```sh
ansible-playbook playbooks/site.yml --limit srv1,minecraft-server1-relay,minecraft-server1-egress,minecraft-server1
```

The playbook sets up the relay first. The egress VM's part fails while the
relay does not answer, and the server itself is skipped until the tunnel
is up, because it is installed through it.

### With the other end run by somebody else

Either end also works alone, from plain settings.

**Your home end, their relay.** In `host_vars/minecraft-server1-egress.yml`,
remove `egress_relay`, and set `egress_vpn_address` to the address they
give this VM in the tunnel. Run its playbook: it shows the VM's public key.
Give the relay's operator that key, the address, and the ports to pass on
(`egress_inbound`). From what they send back, set
`egress_vpn_peer_public_key` and `egress_vpn_endpoint`, and run it again.

**Their home end, a relay from this repository.** The role needs nothing
else from here: any Ubuntu server with a public address, the roles
`tunnel_key` and `relay`, and these settings instead of `relay_egress`:

```yaml
relay_address: 10.99.226.1/24  # this end's address in the tunnel
relay_port: 51820
# From the home end's operator:
relay_peer_public_key: <WireGuard public key>
relay_peer_address: 10.99.226.2  # the home end's address in the tunnel
relay_forwards:
  - proto: tcp
    port: 25565  # Minecraft Java players
  - proto: udp
    port: 19132  # Minecraft Bedrock players
```

The run shows the relay's public key. The home end's operator needs that,
the server's public address with `relay_port`, and `relay_address` without
its prefix. The server's own firewall has to let in `relay_port` on UDP,
the forwarded ports, and SSH for whoever runs Ansible.

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
uploaded. In `group_vars/minecraft/`:

* In `main.yml`, set `minecraft_backup_repository` to the bucket,
  `s3:https://<endpoint>/<bucket>`, and `minecraft_backup_region` to its
  region. The Terraform stack makes one at Hetzner.
* In `secrets.sops.yaml`, put a key pair that may read and write that
  bucket, and a long random `minecraft_backup_password`
  ([secrets](secrets.md)). Keep that password somewhere else too: without
  it no backup can be read.

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
in the Terraform stack:

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

The role also runs on any Ubuntu machine with 6 GB of memory or more,
without a tunnel:

* Add the machine to the `minecraft` group in `inventory/hosts.yml`, and
  only to that group.
* Give it a `host_vars/<name>.yml` with `ansible_host` and `ansible_user`,
  and `minecraft_data_device` if the worlds go on a disk of their own.
* In the provider's firewall, open `25565` TCP and `19132` UDP to everyone,
  and `22` TCP to your own address only. Nothing in this repository
  firewalls that machine.
* Run the playbook with `--limit <name>`.
