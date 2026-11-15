# homelab-VMs

<div align="center">

[![Analysis](https://github.com/Ricardo-van-Aken/homelab-VMs/actions/workflows/analysis.yml/badge.svg?branch=main)](https://github.com/Ricardo-van-Aken/homelab-VMs/actions/workflows/analysis.yml)
[![Molecule](https://github.com/Ricardo-van-Aken/homelab-VMs/actions/workflows/molecule.yml/badge.svg?branch=main)](https://github.com/Ricardo-van-Aken/homelab-VMs/actions/workflows/molecule.yml)
[![ansible-lint](https://img.shields.io/badge/ansible--lint-production-EE0000?logo=ansible&logoColor=white)](https://ansible.readthedocs.io/projects/lint/)
<br>
[![Ansible](https://img.shields.io/badge/ansible-%23EE0000.svg?logo=ansible&logoColor=white)](https://www.ansible.com)
[![Molecule](https://img.shields.io/badge/molecule-testing-000000?logo=ansible&logoColor=white)](https://ansible.readthedocs.io/projects/molecule/)
[![Ubuntu 26.04](https://img.shields.io/badge/ubuntu-26.04_LTS-E95420?logo=ubuntu&logoColor=white)](https://releases.ubuntu.com/26.04/)
[![Docker](https://img.shields.io/badge/docker-%230db7ed.svg?logo=docker&logoColor=white)](https://www.docker.com)
[![License](https://img.shields.io/github/license/Ricardo-van-Aken/homelab-VMs)](LICENSE)
</div>

Ansible for my homelab: a Proxmox host, the Virtual Machines (VMs) on it, a
Raspberry Pi beside it, and two rented servers made with OpenTofu. Each
machine runs one or more services:

* **arcade**: media and game streaming, with the host's graphics processing
unit (GPU) passed through
  * Jellyfin: media server with hardware transcoding
  * Steam: game library
  * Sunshine: streams the desktop and games to Moonlight clients
* **forgejo-git**: code hosting
  * Forgejo: Git forge with web User Interface (UI) and Secure Shell (SSH) access
* **nas**: network share of the media library, for filling it from a laptop
  * Samba: Server Message Block (SMB) shares of the movies, series and music
  datasets
* **recipes**: the household cookbook
  * Mealie: recipe manager and meal planner; the whole Local Area Network
  (LAN) reads and edits
    without signing in
* **dns**: name resolution for the LAN, and the way in
  * Pi-hole: resolver with a name for every machine and service, and ad
  blocking
  * WireGuard: Virtual Private Network (VPN) into the LAN from outside, with
  wg-easy's web UI for adding devices
* **pi1**: the Raspberry Pi, the fallback for both while the Proxmox host
  is down
  * Pi-hole: second resolver with the same records
  * WireGuard: second tunnel, with its own clients
* **monitoring**: for Grafana, Prometheus and Loki; nothing installed yet
* **torrent** and **torrent-egress**: torrent runs on an isolated network of
  its own and has nothing installed yet. torrent-egress is its only way in
  and out, through a VPN provider's WireGuard tunnel set in its host vars.
* **minecraft-server1**, **minecraft-server1-egress** and
  **minecraft-server1-relay**: minecraft-server1 runs a modded Minecraft
  server for Java and Bedrock players, on an isolated network of its own.
  minecraft-server1-egress is its only way in and out, through a WireGuard
  tunnel to minecraft-server1-relay, a rented server. Players connect to
  the relay, so the home address stays hidden.
* **minecraft-server1-standby**: the same Minecraft server, rented, for when the
  one at home is down. It loads the world from the backups both keep in
  one bucket.

Every web UI is served over HTTPS by a Caddy on its machine, with Let's
Encrypt certificates obtained through the domain's DNS records, so at home
nothing but the VPN is reachable from the internet.

<details open>
<summary style="margin-top:2.5em; border-bottom:1px solid rgba(128,128,128,.4); padding-bottom:.3em"><h2 id="prerequisites" style="display:inline; border-bottom:none; margin:0; vertical-align:middle">Prerequisites</h2></summary>

This section contains the prerequisites for setting up the complete ansible
playbook as described in [Full Setup](#full-setup). If you only want to set
up certain VMs, follow the instructions at
[Set up only select VMs](#set-up-only-select-vms).

**Host Hardware**
* A host running Proxmox Virtual Environment (PVE) (I have Proxmox VE 9.2.*)
* A Central Processing Unit (CPU) and board that support Input-Output Memory Management Unit (IOMMU) (Intel VT-d or AMD-Vi).
* Empty disks for the Zettabyte File System (ZFS) pool, two for a mirror
  (Redundant Array of Independent Disks level 1, RAID1).
* A GPU the host can spare.

**Host Basic Input/Output System (BIOS)**
* Virtualisation enabled (Intel VT-x or AMD-V).
* IOMMU enabled (Intel VT-d or AMD-Vi).

**Access**
* Root SSH access on the Proxmox host. We have several roles for configuration
  of the proxmox host, including setting up GPU passthrough, storage pools,
  cloud-init templates, and VMs. This requires shell access on the host.
* Physical access to the host to power cycle it once.

**Your machine**
* ansible-core, or Docker.
* [SOPS](https://github.com/getsops/sops) and
  [age](https://github.com/FiloSottile/age), for the secrets.
* [OpenTofu](https://opentofu.org/docs/intro/install/) 1.13.9,
  only for the rented servers.

</details>

<details open>
<summary style="margin-top:2.5em; border-bottom:1px solid rgba(128,128,128,.4); padding-bottom:.3em"><h2 id="full-setup" style="display:inline; border-bottom:none; margin:0; vertical-align:middle">Full Setup</h2></summary>

You can run the Ansible playbooks from `ansible/` if you have ansible-core
installed. Alternatively, if you have docker installed, you can run it from the
docker image in `ansible/docker/runtime/`.

```sh
cd ansible
```

**(Optional)** build the image and open a shell in it. This allows you to **skip step 1**

```sh
docker build -t ansible-runtime:local --target runtime \
  -f docker/runtime/Dockerfile .
```

The container uses your SSH agent; load the key first (`ssh-add -l` lists
it). It also takes the unlocked SOPS key from your terminal
([docs/secrets.md](docs/secrets.md)). On macOS the agent is reached through
a fixed path, on Linux through your own socket:

```sh
agent=$SSH_AUTH_SOCK; [ "$(uname)" = Darwin ] && agent=/run/host-services/ssh-auth.sock
```

```sh
docker run --rm -it -v "$PWD/..:/work" -w /work/ansible \
  -v "$agent:/ssh-agent" -e SSH_AUTH_SOCK=/ssh-agent \
  -e SOPS_AGE_KEY \
  ansible-runtime:local
```

#### Step 1: install the Galaxy dependencies

Once:

```sh
ansible-galaxy install -r requirements.yml
```

#### Step 2: change the variables

Go through the files in `ansible/inventory/` and change the values to
yours; every variable is explained where it is set. The sections under
[Set up only select VMs](#set-up-only-select-vms) say what each machine
needs.

**Secrets.** They are in the files ending in `.sops.yaml` and `.sops.json`,
encrypted with [SOPS](https://github.com/getsops/sops) for my key. You
cannot read them, so delete them and make your own:
[docs/secrets.md](docs/secrets.md) says how, and which file holds what.

> [!WARNING]
> Every key in the `ssh_keys_authorized` list can log in to your Proxmox
> host and VMs. Put your own public keys in it, in
> `inventory/group_vars/all/identity.sops.yaml` (see Secrets).
>
> You already need SSH access to the Proxmox host, so the public key you use
> for that works here too.

<details>
<summary><strong>Optional: generate an SSH key and keep it in the repository</strong></summary>

If you don't have an SSH key for your homelab yet, make one and put its public
key (`~/.ssh/homelab_ed25519.pub`) in `ssh_keys_authorized`:

```sh
ssh-keygen -t ed25519 -C "homelab" -f ~/.ssh/homelab_ed25519
ssh-add ~/.ssh/homelab_ed25519
```

`ansible/homelab_ed25519.sops.json` is my own SSH private key, encrypted with
SOPS so I can share it between my computers. You cannot decrypt it,
and Ansible never reads it, so delete it. To share yours between your own
computers the same way, encrypt it, from `ansible/`:

```sh
sops encrypt --input-type binary --output-type json --output homelab_ed25519.sops.json ~/.ssh/homelab_ed25519
```

On another computer, restore it with:

```sh
(umask 077; sops decrypt --output-type binary --output ~/.ssh/homelab_ed25519 homelab_ed25519.sops.json)
```

</details>

#### Step 3: set up the Proxmox host

```sh
ansible-playbook playbooks/site.yml --limit proxmox
```

This configures the host (with GPU passthrough it reboots once), builds the
template, and clones and starts every VM in the inventory.

#### Step 4 (optional): power cycle the host

Before the passthrough setup the
host initialised the card, and such a card keeps that state across reboots.
The VM's driver then cannot load its firmware. Losing power once resets it.

Shut down the VMs, power the host off, wait until it is fully off, and power
it on again. GPUs with a function-level reset are reset by the host and skip
this step.

> [!NOTE]
> This has been tested with an AMD Radeon R9 380X (Tonga), which has no
> function-level reset and needs this step. I don't know how this will work
> for other GPUs.

#### Step 5: set up the VMs

The other VMs resolve names through the dns VM, so it goes first:

```sh
ansible-playbook playbooks/site.yml --limit dns
```

```sh
ansible-playbook playbooks/site.yml --limit vms
```

Then make your router hand out `10.0.1.100` (the dns VM) as the DNS server
in its DHCP settings.

minecraft-server1-egress fails until its rented relay exists
([minecraft-server1](#minecraft-server1)). Until then, leave it out with
`--limit 'vms:!minecraft-server1-egress'`.

> [!TIP]
> Every run decrypts the secrets, so unlock the SOPS key in that terminal
> first ([docs/secrets.md](docs/secrets.md)). A run that says it failed to
> get the data key means the key is not unlocked.

#### Step 6 (optional): set up the Raspberry Pi
The Raspberry Pi adds a second DNS server and a second VPN, for when the
Proxmox host and its VMs are down. To leave it out completely, remove
`pi1` from `inventory/hosts.yml`.

The first run gives the Pi its fixed IP address (`host_vars/pi1.yml`), so it
needs the Pi's current address on the first run:

```sh
ansible-playbook playbooks/site.yml --limit pi1 -e static_address_current=<current address>
```

Any subsequent runs can use:

```sh
ansible-playbook playbooks/site.yml --limit pi1
```

Then, in your router:
* DNS: add `10.0.1.101` as a second DNS server in the DHCP settings.
* VPN: forward UDP port `51821` to `10.0.1.101:51821`.

#### Step 7 (optional): HTTPS

Every web UI gets a Let's Encrypt certificate, proven through your DNS
provider's API, so nothing has to be reachable from the internet.

* Set `caddy_https: true` in `group_vars/all/main.yml`.
* Set `caddy_dns_provider` and `caddy_dns_plugin` to your provider's
  [caddy-dns](https://github.com/caddy-dns) plugin, and replace the
  encrypted `caddy_dns_token` in `group_vars/all/secrets.sops.yaml` with an
  API token of that provider (see Secrets).
* Replace the encrypted `caddy_acme_email` there with yours.

```sh
ansible-playbook playbooks/site.yml --limit vms:pis
```

</details>

<details>
<summary style="margin-top:2.5em; border-bottom:1px solid rgba(128,128,128,.4); padding-bottom:.3em"><h2 id="set-up-only-select-vms" style="display:inline; border-bottom:none; margin:0; vertical-align:middle">Set up only select VMs</h2></summary>

Every VM needs the [Proxmox host](#proxmox-host) set up first. Each VM is a
host in `inventory/hosts.yml`, with
`host_vars/<vm>.yml` describing the machine:
* `ansible_host`: the VM's address. Needed by ansible for ssh.
* `pve_vm`: cores, memory, GPU, shares

Any configuration of the services within the VM have to be adjusted in
`inventory/group_vars/<service>.yml`, or `<service>/main.yml` for a service
with secrets.

<details>
<summary><h3 id="proxmox-host" style="display:inline; margin:0; vertical-align:middle">Proxmox host</h3></summary>

Make sure the host runs Proxmox VE. Before the first run:
* **Root SSH access on the Proxmox host.** We have several roles for
  configuration of the proxmox host, including setting up GPU passthrough,
  storage pools, cloud-init templates, and VMs. This requires shell access on
  the host.
* **Empty disks for the pool.** The storage role refuses disks that carry a
  filesystem or pool label; wipe them deliberately first.
* **Variables**
  
  `host_vars/srv1.yml`
    * `ansible_host`: the Proxmox host's address
    * `pve_storage_pools`: disk ids, from `ls -l /dev/disk/by-id`
    * `pve_passthrough_devices`: only for a VM with a GPU (arcade); the
      GPU's Peripheral Component Interconnect (PCI) functions, from `lspci -D`. Leave empty to skip passthrough
  
  `group_vars/all/identity.sops.yaml` (see Secrets)
    * `ssh_keys_authorized`: public keys that may log in to the Proxmox host
      and the VMs

  `group_vars/all/main.yml`
    * `homelab_lan`: your LAN. Devices on it may SSH in and open the
      Proxmox web UI; anything else is firewalled off.
  
  `group_vars/proxmox.yml`
    * `pve_vms_gateway`: the VMs' default gateway
    * `pve_vms_nameservers`: the VMs' DNS servers

```sh
ansible-playbook playbooks/site.yml --limit proxmox
```

This also clones and starts every VM in the inventory. With passthrough
devices listed, the first run reboots the host and needs one cold power cycle
afterwards (see [Full Setup](#full-setup), Step 4).

</details>

<details>
<summary><h3 id="arcade" style="display:inline; margin:0; vertical-align:middle">arcade</h3></summary>

* Attach a dummy High-Definition Multimedia Interface (HDMI) plug or set `desktop_force_connector`.
* `restart_on_change` in `host_vars/arcade.yml` is `false` because my card
  cannot be reset: the proxmox play then never restarts arcade, changed VM
  settings wait for the next cold power cycle of the host. With a card that
  resets cleanly, set it to `true`.
* Steam gets the games share as a second library. After the first start,
  make it the default under Settings, Storage, so installs go to the pool.
* Replace the encrypted `jellyfin_admin_password` and `jellyfin_users` in
  `group_vars/jellyfin/secrets.sops.yaml` with your own (see
  Secrets). The role runs Jellyfin's setup wizard with them: admin user,
  extra users, libraries from `jellyfin_libraries`, hardware transcoding.
  Leave the admin password empty to do the wizard in the browser instead.
* The first run installs GPU firmware and reboots once, as does any run that
  finds the GPU driver not yet bound.

```sh
ansible-playbook playbooks/site.yml --limit arcade
```

</details>

<details>
<summary><h3 id="forgejo-git" style="display:inline; margin:0; vertical-align:middle">forgejo-git</h3></summary>

* Replace the encrypted `forgejo_admin_email` and `forgejo_admin_password` in
  `group_vars/forgejo/secrets.sops.yaml` with your own (see Secrets), or create the admin
  by hand afterwards.
* Add your own accounts to `forgejo_users` in the same file, name, email and
  password each encrypted. Every account needs its own address.

```sh
ansible-playbook playbooks/site.yml --limit forgejo-git
```

</details>

<details>
<summary><h3 id="nas" style="display:inline; margin:0; vertical-align:middle">nas</h3></summary>

* Replace the encrypted `samba_password` in `group_vars/samba/secrets.sops.yaml` with your
  own (see Secrets). It is set once; change it later with `smbpasswd media`
  on the VM.

```sh
ansible-playbook playbooks/site.yml --limit nas
```

Then connect from a laptop with `smb://10.0.1.120/movies` (or `series`,
`music`) as user `media`. Files land in the datasets owned by Jellyfin's
user ID (uid), so they show up in the library on the next scan.

</details>

<details>
<summary><h3 id="recipes" style="display:inline; margin:0; vertical-align:middle">recipes</h3></summary>

* Replace the encrypted `mealie_admin_password` and `mealie_proxy_secret` in
  `group_vars/mealie/secrets.sops.yaml` with your own (see Secrets). The secret is any
  long random string.

```sh
ansible-playbook playbooks/site.yml --limit recipes
```

Then open `http://mealie.<domain>`. Everyone on the LAN is signed in as the
shared `family` account and can add and edit recipes. To use the admin
account, log out from the menu and sign in on the page that follows.

</details>

<details>
<summary><h3 id="dns" style="display:inline; margin:0; vertical-align:middle">dns</h3></summary>

* Replace the encrypted `pihole_web_password` in
  `group_vars/pihole/secrets.sops.yaml` with your own (see Secrets).
* Replace the encrypted `wireguard_admin_password` in
  `group_vars/wireguard/secrets.sops.yaml` with your own (see Secrets), and set
  `wireguard_public_host` to your public IP address, or a public DNS name
  pointing at it.
* Put your domain in `group_vars/all/identity.sops.yaml` as
  `homelab_domain` (see Secrets). Every machine and service becomes
  a subdomain of it, `forgejo.<domain>` for example.

```sh
ansible-playbook playbooks/site.yml --limit dns
```

Then, in your router:
* DNS: hand out `10.0.1.100` as the Domain Name System (DNS) server in the
  Dynamic Host Configuration Protocol (DHCP) settings.
* VPN: forward UDP port `51820` to `10.0.1.100`. Devices are added in the
  wg-easy UI.

Some routers cannot hand out a DNS server that is on your own network. An
Apple AirPort always hands out itself, and only passes lookups on to DNS
servers on the internet. Then let the Pi-holes hand out the addresses,
which is how this repository is set; with a router that can hand out the
Pi-holes itself, remove the two ranges instead.

* Set `pihole_dhcp_start` and `pihole_dhcp_end` in `host_vars/dns.yml` and
  `host_vars/pi1.yml` to two ranges that do not overlap.
* Set `pihole_dhcp_router` and `pihole_dhcp_dns` in
  `group_vars/pihole/main.yml` to your router and your Pi-holes.
* Run the playbook for `dns` and `pi1`. `pi1` answers a few seconds late
  (`pihole_dhcp_reply_delay`), so it only hands out addresses while `dns`
  is down.
* Turn the router's own DHCP server off. An AirPort cannot do that while
  it shares one address: shrink its DHCP range to a single address outside
  the Pi-holes' ranges, and reserve that address for a hardware address no
  device has.

</details>

<details>
<summary><h3 id="pi1" style="display:inline; margin:0; vertical-align:middle">pi1</h3></summary>

A Raspberry Pi with Raspberry Pi OS (64-bit), SSH enabled and your public
key installed.

* Set `ansible_user` in `group_vars/pis.yml` to the Pi's user.
* Keep `static_address_ip` (`host_vars/pi1.yml`) out of your router's DHCP
  pool.
* The Pi-hole and wg-easy passwords are the ones set for [dns](#dns).

The first run gives the Pi its fixed address, so it needs the Pi's current
address:

```sh
ansible-playbook playbooks/site.yml --limit pi1 -e static_address_current=<current address>
```

After that:

```sh
ansible-playbook playbooks/site.yml --limit pi1
```

Then, in your router:
* DNS: add `10.0.1.101` as a second DNS server in the DHCP settings.
* VPN: forward UDP port `51821` to `10.0.1.101:51821`.

New VPN clients get the two Pi-holes as DNS servers
(`wireguard_client_dns` in `group_vars/wireguard/main.yml`), so homelab names
resolve through the tunnel. wg-easy takes this from Ansible on its first
start only; on an instance that is already set up, change it in its web UI
under the client defaults instead.

</details>

<details>
<summary><h3 id="minecraft-server1" style="display:inline; margin:0; vertical-align:middle">minecraft-server1, with its egress, relay and standby</h3></summary>

A Minecraft server for Java and Bedrock players on an isolated VM. Its
egress VM tunnels to minecraft-server1-relay, a rented server players
connect to at `ddg-craft.<domain>`, so your router forwards nothing and your home
address shows up nowhere. minecraft-server1-standby is the same server, rented,
for when the one at home is down.

* Make the rented servers ([Cloud resources](#cloud-resources)).
* In `group_vars/minecraft/main.yml`, read Mojang's
  [End User License Agreement (EULA)](https://aka.ms/MinecraftEULA) and set
  `minecraft_eula` to `true` to agree, and set the seed and the world's
  border.
* Replace the encrypted backup secrets in
  `group_vars/minecraft/secrets.sops.yaml` with your own (see Secrets).

```sh
ansible-playbook playbooks/site.yml --limit srv1,minecraft-server1-relay,minecraft-server1-egress,minecraft-server1
```

[docs/minecraft.md](docs/minecraft.md) has the rest: the whitelist and
other commands for the running server, backups and going back to one, the
standby, and running either end of the tunnel without the other.

</details>

</details>

<details>
<summary style="margin-top:2.5em; border-bottom:1px solid rgba(128,128,128,.4); padding-bottom:.3em"><h2 id="cloud-resources" style="display:inline; border-bottom:none; margin:0; vertical-align:middle">Cloud resources</h2></summary>

What is rented outside the house, at Hetzner, is made with OpenTofu under
`terraform/`, one stack per purpose: `dns` for the domain's Domain Name
System (DNS) zone, and `minecraft` for the backup bucket, the relay and
the standby server. OpenTofu reads the domain, the SSH keys and the
servers' names from the Ansible inventory, so nothing is kept twice.
[docs/cloud-resources.md](docs/cloud-resources.md) says what to make in
the Hetzner console first and how to run a stack.

</details>

<details open>
<summary style="margin-top:2.5em; border-bottom:1px solid rgba(128,128,128,.4); padding-bottom:.3em"><h2 id="domains" style="display:inline; border-bottom:none; margin:0; vertical-align:middle">Domains</h2></summary>

Built from the inventory by the Pi-holes, under `homelab_domain`:
`<machine>` for every machine and `<service>` for every service, or
`<machine>.<service>` where a service runs on several machines. Every name
points at one address. These names only resolve on the LAN and through
the VPN.

**Machines**, for SSH:

| Subdomain   | Address    |
|-------------|------------|
| dns         | 10.0.1.100 |
| pi1         | 10.0.1.101 |
| forgejo-git | 10.0.1.110 |
| nas         | 10.0.1.120 |
| recipes     | 10.0.1.130 |
| monitoring  | 10.0.1.140 |
| arcade      | 10.0.1.160 |
| torrent-egress | 10.0.1.225 |
| minecraft-server1-egress | 10.0.1.226 |
| torrent     | 10.250.225.150, through torrent-egress |
| minecraft-server1 | 10.250.226.170, through minecraft-server1-egress |

**Web UIs**, open in the browser:

| Subdomain  | Address    | Service                 |
|------------|------------|-------------------------|
| dns.pihole | 10.0.1.100 | Pi-hole admin, `/admin` |
| dns.wireguard | 10.0.1.100 | wg-easy              |
| pi1.pihole | 10.0.1.101 | Pi-hole admin, `/admin` |
| pi1.wireguard | 10.0.1.101 | wg-easy              |
| forgejo    | 10.0.1.110 | Forgejo                 |
| mealie     | 10.0.1.130 | Mealie                  |
| jellyfin   | 10.0.1.160 | Jellyfin                |
| gaming     | 10.0.1.160 | Sunshine, for pairing   |

**Other connections**:

| Subdomain  | Address    | Use                                         |
|------------|------------|---------------------------------------------|
| dns.pihole | 10.0.1.100 | DNS server                                  |
| pi1.pihole | 10.0.1.101 | DNS server                                  |
| forgejo    | 10.0.1.110 | git over SSH, port 2222                     |
| samba      | 10.0.1.120 | SMB shares, `smb://samba.<domain>`          |
| jellyfin   | 10.0.1.160 | the Jellyfin apps, port 8096                |
| gaming     | 10.0.1.160 | Moonlight pairing                           |

The VPNs themselves connect to your public address, not to a name here:
the dns VM's on UDP port 51820, the Pi's on 51821.

Four names are public, in the domain's zone at the DNS provider:
`wg-easy` (your public address, for the VPN), `ddg-craft` (the Minecraft relay),
`map.ddg-craft` (the Minecraft map, on the relay too) and `ddg-craft-standby` (the standby).

</details>

<details>
<summary style="margin-top:2.5em; border-bottom:1px solid rgba(128,128,128,.4); padding-bottom:.3em"><h2 id="layout" style="display:inline; border-bottom:none; margin:0; vertical-align:middle">Layout</h2></summary>

```
.
├── ansible/
│   ├── ansible.cfg          inventory, role and collection search paths
│   ├── requirements.yml     Galaxy roles and collections
│   ├── inventory/
│   │   ├── hosts.yml        proxmox hosts, and VMs in one group per service
│   │   ├── group_vars/      VM settings (ports, users, data paths, GPU pins); a
│   │   │                    group with secrets is a directory: main.yml, and
│   │   │                    the secrets in *.sops.yaml
│   │   └── host_vars/       per machine 'physical' settings: Internet Protocol (IP) address and 
|   |                        hardware (PCI devices, disks, CPU cores, memory)
|   |
│   ├── playbooks/site.yml   maps groups to roles
│   ├── roles/
│   │   ├── proxmox/         the Proxmox host: passthrough, storage, template, VMs
│   │   ├── common/          building blocks any machine may use
│   │   └── services/        one role per service
│   ├── molecule/            one test scenario per container-testable role
│   └── docker/              images for code analysis, running ansible, and
|                            a target for molecule
├── terraform/
│   ├── stacks/              one directory per purpose, each applied on its own:
│   │                        dns, minecraft
│   ├── modules/             building blocks the stacks share
│   └── secrets/             what OpenTofu logs in with, encrypted with SOPS
├── docs/                    guides: secrets, cloud resources, Minecraft
├── .config/molecule/        settings shared by every scenario (Molecule reads
│                            this from the git root only)
├── .github/
│   ├── workflows/           analysis, molecule, and the shared image build
│   └── scripts/             helpers for the workflows
└── .yamllint                one YAML style for the whole repo
```

<details>
<summary><h3 id="own-roles" style="display:inline; margin:0; vertical-align:middle">Own roles</h3></summary>

In the order the playbook runs them. They live in three directories under
`roles/`, each on the roles path: `proxmox/` (the `pve_*` roles),
`common/` (building blocks) and `services/` (one per service).

| Role            | Purpose                                                      |
|-----------------|--------------------------------------------------------------|
| ssh_keys        | lets the public keys in `ssh_keys_authorized` log in         |
| pve_passthrough | Proxmox host: IOMMU, vfio binding, driver blacklist, console |
| pve_storage     | Proxmox host: ZFS pools, datasets, virtiofs mappings         |
| pve_network     | Proxmox host: bridges for the isolated networks              |
| pve_template    | Proxmox host: Ubuntu cloud-init template VMs are cloned from |
| pve_firewall    | Proxmox host: its own firewall, and one rule file per VM     |
| pve_vms         | Proxmox host: clones and reconciles the VMs in the inventory |
| static_address  | Raspberry Pi: fixed address on its NetworkManager connection |
| host_firewall   | Raspberry Pi: nftables firewall that drops what is not listed |
| base            | guest agent (VMs only), unattended upgrades, timezone        |
| shares          | mounts the VM's virtiofs shares from `pve_vm.shares`         |
| tunnel_key      | makes a WireGuard key pair on a machine and reads its public half; used by both ends of a tunnel |
| relay           | public end of an egress VM's tunnel, on a rented server: passes chosen ports down the tunnel and lets the tunnel's traffic out under its own address |
| egress          | gateway of one isolated network: forwards it into a WireGuard tunnel and nowhere else, and passes chosen ports back in |
| minecraft       | Minecraft compose stack: Fabric server with checksummed mods, Bedrock players through Geyser, whitelist only, backups |
| gpu             | firmware, userspace and i386 packages for `gpu_vendors`      |
| desktop         | Xorg + LightDM autologin + openbox session for `gamer`       |
| steam           | Steam with i386 libraries, gamemode, mangohud; client installed up front, games share registered as a library |
| sunshine        | Sunshine .deb, config, apps, user service; web UI behind Caddy |
| caddy           | reverse proxy with HTTPS (Let's Encrypt, DNS challenge), one site file per service; pulled in by the web service roles |
| jellyfin        | Jellyfin compose stack, GPU node; wizard, libraries, users via Application Programming Interface (API) |
| forgejo         | Forgejo compose stack (sqlite, closed registration, admin and users) |
| samba           | SMB shares of the mounted media datasets                     |
| mealie          | Mealie behind a Caddy proxy that signs the LAN in as one shared account; admin takeover, accounts and public access via API |
| pihole          | Pi-hole compose stack with local records from the inventory, admin UI behind Caddy; frees port 53 from systemd-resolved |
| wireguard       | wg-easy compose stack: WireGuard with a web UI behind Caddy |

</details>

<details>
<summary><h3 id="external-roles" style="display:inline; margin:0; vertical-align:middle">External roles</h3></summary>

Pinned in `requirements.yml`, installed to `galaxy_roles/` locally and baked
into the container images.

| Role               | Purpose                            |
|--------------------|------------------------------------|
| geerlingguy.docker | Docker engine and compose plugin   |

</details>

</details>

<details>
<summary style="margin-top:2.5em; border-bottom:1px solid rgba(128,128,128,.4); padding-bottom:.3em"><h2 id="testing" style="display:inline; border-bottom:none; margin:0; vertical-align:middle">Testing</h2></summary>

Roles that can run in a container have a Molecule scenario under
`ansible/molecule/`. Shared settings live in `.config/molecule/config.yml`.
Instances are containers which represent our VMs image as closely as possible:
`ansible/docker/molecule-target`: Ubuntu 26.04 with systemd and python3. 
Build it once, then run a scenario from the molecule image:

```sh
cd ansible
docker build -t molecule-target:local docker/molecule-target
docker run --rm -it --user root -v "$PWD/..:/work" -w /work/ansible \
  -v /var/run/docker.sock:/var/run/docker.sock \
  ghcr.io/ricardo-van-aken/homelab-vms/ansible-molecule:<tag> \
  molecule test --scenario-name base
```

| Scenario | Notes                                                        |
|----------|--------------------------------------------------------------|
| base     |                                                              |
| gpu      | package-level checks; no GPU in the instance                 |
| steam    | needs an amd64 host (i386 packages)                          |
| jellyfin | logs in as the admin the role made; the libraries and extra user exist |
| forgejo  | admin and regular user exist, public registration is blocked |
| samba    | logs in as `media` and copies a file to the share; Jellyfin owns the file afterwards |
| mealie   | a visit without credentials lands on the shared account through a reverse proxy(Caddy) |
| pihole   | a local record and a public name resolve; the admin password logs in through Caddy |
| wireguard | wg-easy runs with the tunnel published and the UI behind Caddy. Needs the WireGuard module on the host running the instance |
| minecraft | the server starts with every mod loaded and Geyser listening; a player is whitelisted on the running server. Agrees to Mojang's EULA, and downloads about 1.5 GB |

</details>

<details>
<summary style="margin-top:2.5em; border-bottom:1px solid rgba(128,128,128,.4); padding-bottom:.3em"><h2 id="additional-info" style="display:inline; border-bottom:none; margin:0; vertical-align:middle">Additional info</h2></summary>

<details>
<summary><strong>Hardware</strong></summary>

* **srv1**
  * CPU: Intel Core Ultra 7 265KF (VT-x, VT-d)
  * Motherboard: Asus Prime Z890M-Plus WIFI
  * Memory: Corsair Vengeance DDR5 2x16 GB 6000 MHz CL38 (CMK32GX5M2B6000Z38)
  * GPU: AMD Radeon R9 380X (Tonga)
  * Solid-State Drive (SSD): Lexar NQ780 1 TB M.2 2280 PCIe 4.0 x4 NVMe
  * Hard Disk Drive (HDD): 2x Seagate IronWolf 8 TB (ST8000VN004-2M2101)
* **pi1**
  * Raspberry Pi 3 Model B+ (quad-core Cortex-A53, 1 GB RAM)

</details>

<details>
<summary><strong>Ports</strong></summary>

Listed as port/protocol: Transmission Control Protocol (TCP) or User Datagram
Protocol (UDP).

On every machine with a web UI, 80/tcp redirects to 443/tcp (Caddy).

* **dns** (10.0.1.100)
  * 22/tcp: SSH
  * 53/tcp, 53/udp: DNS
  * 67/udp: DHCP
  * 443/tcp: Pi-hole admin UI and API, and the wg-easy UI, through Caddy
  * 51820/udp: WireGuard, forwarded by the router
* **pi1** (10.0.1.101)
  * 22/tcp: SSH
  * 53/tcp, 53/udp: DNS
  * 67/udp: DHCP
  * 443/tcp: Pi-hole admin UI and API, and the wg-easy UI, through Caddy
  * 51821/udp: WireGuard, forwarded by the router
* **forgejo-git** (10.0.1.110)
  * 22/tcp: SSH to the VM
  * 443/tcp: Forgejo web UI and Hypertext Transfer Protocol (HTTP) clone, through Caddy
  * 2222/tcp: Forgejo SSH clone
* **nas** (10.0.1.120)
  * 22/tcp: SSH
  * 445/tcp: SMB shares
* **recipes** (10.0.1.130)
  * 22/tcp: SSH
  * 443/tcp: Mealie web UI and API, through Caddy
* **arcade** (10.0.1.160)
  * 22/tcp: SSH
  * 443/tcp: Jellyfin web UI, through Caddy
  * 8096/tcp: Jellyfin web UI and API, for the apps
  * 7359/udp: Jellyfin client auto-discovery
  * 1900/udp: Jellyfin Digital Living Network Alliance (DLNA)
  * 47990/tcp: Sunshine web UI with its own certificate; also on 443 through Caddy
  * 47984/tcp, 47989/tcp: Sunshine pairing and control (Moonlight)
  * 48010/tcp: Sunshine Real-Time Streaming Protocol (RTSP)
  * 47998-48000/udp: Sunshine video, control and audio streams
* **minecraft-server1-relay** (rented, public)
  * 22/tcp: SSH, from home only
  * 51820/udp: WireGuard, from minecraft-server1-egress
  * 25565/tcp, 19132/tcp+udp: Minecraft, passed down the tunnel
  * 80/tcp, 443/tcp: the Minecraft map, through Caddy
* **minecraft-server1-egress** (10.0.1.226)
  * 22/tcp: SSH
* **minecraft-server1** (10.250.226.170), through the tunnel only
  * 22/tcp: SSH, from minecraft-server1-egress
  * 25565/tcp: Minecraft, Java players
  * 19132/tcp+udp: Minecraft, Bedrock players (Geyser)
  * 80/tcp: BlueMap, a map of the world in a browser; the relay adds HTTPS
* **srv1** (10.0.1.200), the Proxmox host
  * 22/tcp: SSH
  * 8006/tcp: Proxmox web UI and API (HTTPS, its own certificate)

</details>

**Disclaimer.** Much of the code and documentation in this repository was
generated with Artificial Intelligence (AI) assistance and then reviewed, tested and adjusted by hand.

</details>
