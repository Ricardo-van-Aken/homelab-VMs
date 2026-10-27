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

Ansible for my homelab: a Proxmox host, the Virtual Machines (VMs) on it, and
a Raspberry Pi beside it. Each machine runs one or more services:

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
* **dns**: name resolution for the LAN
  * Pi-hole: resolver with a name for every machine and service, and ad
  blocking
* **pi1**: the Raspberry Pi, independent of the Proxmox host
  * Pi-hole: second resolver with the same records, so names keep resolving
  while the host is down
  * WireGuard: Virtual Private Network (VPN) into the LAN from outside, with
  wg-easy's web UI for adding devices

Every web UI is served over HTTPS by a Caddy on its machine, with Let's
Encrypt certificates obtained through the domain's DNS records, so nothing
but the VPN is reachable from the internet.

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
it). On macOS the agent is reached through a fixed path, on Linux through
your own socket:

```sh
agent=$SSH_AUTH_SOCK; [ "$(uname)" = Darwin ] && agent=/run/host-services/ssh-auth.sock
```

```sh
docker run --rm -it -v "$PWD/..:/work" -w /work/ansible \
  -v "$agent:/ssh-agent" -e SSH_AUTH_SOCK=/ssh-agent \
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

The encrypted values in `inventory/group_vars/` (`!vault` blocks) were made
with my personal vault password, so replace them too. Pick a vault password,
then per secret:

```sh
ansible-vault encrypt_string --ask-vault-pass --stdin-name forgejo_admin_password
```

Type the value, press Ctrl-D, and paste the output over the old block in the
same file.

> [!WARNING]
> Every key in the `ssh_keys_authorized` list can log in to your Proxmox
> host and VMs. Replace my public keys in `inventory/group_vars/all.yml` with
> your own, or I have access to your systems.
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

`ansible/homelab_ed25519.vault` is my own SSH private key, encrypted with my
vault password so I can share it between my computers. You cannot decrypt it,
and Ansible never reads it, so delete it. To share yours between your own
computers the same way, encrypt it with your vault password:

```sh
ansible-vault encrypt --output homelab_ed25519.vault ~/.ssh/homelab_ed25519
```

On another computer, restore it with:

```sh
(umask 077; ansible-vault decrypt --output ~/.ssh/homelab_ed25519 homelab_ed25519.vault)
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

```sh
ansible-playbook playbooks/site.yml --limit vms --ask-vault-pass
```

Then make your router hand out `10.0.1.101` (the dns VM) as the DNS server
in its DHCP settings.

> [!TIP]
> The vault password is needed whenever a play touches an encrypted value
> from the inventory. To avoid the prompt, keep the password in a file
> outside the repo and export `ANSIBLE_VAULT_PASSWORD_FILE=<path>` instead.

#### Step 6 (optional): set up the Raspberry Pi
The Raspberry Pi adds a DNS server and a VPN. Both run independent of the
Proxmox host and its VMs. To leave it out completely, remove `pi1` from
`inventory/hosts.yml`.

The first run gives the Pi its fixed IP address (`host_vars/pi1.yml`), so it
needs the Pi's current address on the first run:

```sh
ansible-playbook playbooks/site.yml --limit pi1 -e static_address_current=<current address> --ask-vault-pass
```

Any subsequent runs can use:

```sh
ansible-playbook playbooks/site.yml --limit pi1 --ask-vault-pass
```

Then, in your router:
* DNS: add `10.0.1.100` as a second DNS server in the DHCP settings.
* VPN: forward UDP port `51820` to `10.0.1.100`.

#### Step 7 (optional): HTTPS

Every web UI gets a Let's Encrypt certificate, proven through your DNS
provider's API, so nothing has to be reachable from the internet.

* Set `caddy_https: true` in `group_vars/all.yml`.
* Set `caddy_dns_provider` and `caddy_dns_plugin` to your provider's
  [caddy-dns](https://github.com/caddy-dns) plugin, and replace the
  encrypted `caddy_dns_token` with an API token of that provider (see
  Secrets).
* Replace the encrypted `caddy_acme_email` with yours.

```sh
ansible-playbook playbooks/site.yml --limit vms:pis --ask-vault-pass
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
`inventory/group_vars/<service>.yml`

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
  
  `group_vars/all.yml`
    * `ssh_keys_authorized`: public keys that may log in to the Proxmox host
      and the VMs
  
  `group_vars/proxmox.yml`
    * `pve_vms_gateway`: the VMs' default gateway

```sh
ansible-playbook playbooks/site.yml --limit proxmox
```

This also clones and starts every VM in the inventory. With passthrough
devices listed, the first run reboots the host and needs one cold power cycle
afterwards (see [Proxmox host roles](#proxmox-host-roles)).

</details>

<details>
<summary><h3 id="arcade" style="display:inline; margin:0; vertical-align:middle">arcade</h3></summary>

* Attach a dummy High-Definition Multimedia Interface (HDMI) plug or set `desktop_force_connector`.
* Replace the placeholder `jellyfin_admin_password` and the passwords in
  `jellyfin_users` in `group_vars/jellyfin.yml` with `!vault` values (see
  Secrets). The role runs Jellyfin's setup wizard with them: admin user,
  extra users, libraries from `jellyfin_libraries`, hardware transcoding.
  Leave the admin password empty to do the wizard in the browser instead.
* The first run installs GPU firmware and reboots once, as does any run that
  finds the GPU driver not yet bound.

```sh
ansible-playbook playbooks/site.yml --limit arcade --ask-vault-pass
```

</details>

<details>
<summary><h3 id="forgejo-git" style="display:inline; margin:0; vertical-align:middle">forgejo-git</h3></summary>

* Replace the encrypted `forgejo_admin_email` and `forgejo_admin_password` in
  `group_vars/forgejo.yml` with your own (see Secrets), or create the admin
  by hand afterwards.
* Add your own accounts to `forgejo_users` in the same file, name, email and
  password each encrypted. Every account needs its own address.

```sh
ansible-playbook playbooks/site.yml --limit forgejo-git --ask-vault-pass
```

</details>

<details>
<summary><h3 id="nas" style="display:inline; margin:0; vertical-align:middle">nas</h3></summary>

* Replace the encrypted `samba_password` in `group_vars/samba.yml` with your
  own (see Secrets). It is set once; change it later with `smbpasswd media`
  on the VM.

```sh
ansible-playbook playbooks/site.yml --limit nas --ask-vault-pass
```

Then connect from a laptop with `smb://10.0.1.120/movies` (or `series`,
`music`) as user `media`. Files land in the datasets owned by Jellyfin's
user ID (uid), so they show up in the library on the next scan.

</details>

<details>
<summary><h3 id="recipes" style="display:inline; margin:0; vertical-align:middle">recipes</h3></summary>

* Replace the encrypted `mealie_admin_password` and `mealie_proxy_secret` in
  `group_vars/mealie.yml` with your own (see Secrets). The secret is any
  long random string.

```sh
ansible-playbook playbooks/site.yml --limit recipes --ask-vault-pass
```

Then open `http://mealie.zeepaardje98.eu`. Everyone on the LAN is signed in as the
shared `family` account and can add and edit recipes. To use the admin
account, log out from the menu and sign in on the page that follows.

</details>

<details>
<summary><h3 id="dns" style="display:inline; margin:0; vertical-align:middle">dns</h3></summary>

* Replace the encrypted `pihole_web_password` in `group_vars/pihole.yml` with
  your own (see Secrets).
* Set `homelab_domain` in `group_vars/all.yml` to your domain. Every machine
  and service becomes a subdomain of it, `forgejo.<domain>` for example.

```sh
ansible-playbook playbooks/site.yml --limit dns --ask-vault-pass
```

Then make your router hand out `10.0.1.101` as the Domain Name System (DNS)
server in its Dynamic Host Configuration Protocol (DHCP) settings.

</details>

<details>
<summary><h3 id="pi1" style="display:inline; margin:0; vertical-align:middle">pi1</h3></summary>

A Raspberry Pi with Raspberry Pi OS (64-bit), SSH enabled and your public
key installed.

* Set `ansible_user` in `group_vars/pis.yml` to the Pi's user.
* Keep `static_address_ip` (`host_vars/pi1.yml`) out of your router's DHCP
  pool.
* Replace the encrypted `pihole_web_password` in `group_vars/pihole.yml` with
  your own (see Secrets).
* To take over an existing wg-easy, point `wireguard_import_compose_dir` and
  `wireguard_import_data_dir` in `group_vars/wireguard.yml` at it; remove
  both after the first run.

The first run gives the Pi its fixed address, so it needs the Pi's current
address:

```sh
ansible-playbook playbooks/site.yml --limit pi1 -e static_address_current=<current address> --ask-vault-pass
```

After that:

```sh
ansible-playbook playbooks/site.yml --limit pi1 --ask-vault-pass
```

Then, in your router:
* DNS: add `10.0.1.100` as a second DNS server in the DHCP settings.
* VPN: forward UDP port `51820` to `10.0.1.100`.

</details>

</details>

<details open>
<summary style="margin-top:2.5em; border-bottom:1px solid rgba(128,128,128,.4); padding-bottom:.3em"><h2 id="domains" style="display:inline; border-bottom:none; margin:0; vertical-align:middle">Domains</h2></summary>

Built from the inventory by the Pi-holes, under `homelab_domain`:
`<machine>` for every machine and `<service>` for every service, or
`<machine>.<service>` where a service runs on several machines. Every name
points at one address.

All subdomains of `zeepaardje98.eu`.

**Machines**, for SSH:

| Subdomain   | Address    |
|-------------|------------|
| pi1         | 10.0.1.100 |
| dns         | 10.0.1.101 |
| forgejo-git | 10.0.1.110 |
| nas         | 10.0.1.120 |
| recipes     | 10.0.1.130 |
| arcade      | 10.0.1.160 |

**Web UIs**, open in the browser:

| Subdomain  | Address    | Service                 |
|------------|------------|-------------------------|
| pi1.pihole | 10.0.1.100 | Pi-hole admin, `/admin` |
| wireguard  | 10.0.1.100 | wg-easy                 |
| dns.pihole | 10.0.1.101 | Pi-hole admin, `/admin` |
| forgejo    | 10.0.1.110 | Forgejo                 |
| mealie     | 10.0.1.130 | Mealie                  |
| jellyfin   | 10.0.1.160 | Jellyfin                |

**Other connections**:

| Subdomain  | Address    | Use                                         |
|------------|------------|---------------------------------------------|
| pi1.pihole | 10.0.1.100 | DNS server                                  |
| dns.pihole | 10.0.1.101 | DNS server                                  |
| forgejo    | 10.0.1.110 | git over SSH, port 2222                     |
| samba      | 10.0.1.120 | SMB shares, `smb://samba.zeepaardje98.eu`   |
| jellyfin   | 10.0.1.160 | the Jellyfin apps, port 8096                |
| gaming     | 10.0.1.160 | Moonlight pairing; Sunshine UI on port 47990 |

The VPN itself connects to your public address, not to a name here.

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
│   │   ├── group_vars/      VM settings (ports, users, data paths, GPU pins)
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
├── .config/molecule/        settings shared by every scenario (Molecule reads
│                            this from the git root only)
├── .github/
│   ├── workflows/           analysis, molecule, and the shared image build
│   └── scripts/             JUnit to job-summary renderer
└── .yamllint                one YAML style for the whole repo
```

<details>
<summary><h3 id="own-roles" style="display:inline; margin:0; vertical-align:middle">Own roles</h3></summary>

In the order the playbook runs them. They live in three directories under
`roles/`, each on the roles path: `proxmox/` (the `pve_*` roles),
`common/` (building blocks) and `services/` (one per service).

| Role            | Purpose                                                      |
|-----------------|--------------------------------------------------------------|
| pve_passthrough | Proxmox host: IOMMU, vfio binding, driver blacklist, console |
| pve_storage     | Proxmox host: ZFS pools, datasets, virtiofs mappings         |
| pve_template    | Proxmox host: Ubuntu cloud-init template VMs are cloned from |
| pve_vms         | Proxmox host: clones and reconciles the VMs in the inventory |
| static_address  | Raspberry Pi: fixed address on its NetworkManager connection |
| base            | guest agent (VMs only), unattended upgrades, timezone        |
| shares          | mounts the VM's virtiofs shares from `pve_vm.shares`         |
| gpu             | firmware, userspace and i386 packages for `gpu_vendors`      |
| desktop         | Xorg + LightDM autologin + openbox session for `gamer`       |
| steam           | Steam with i386 libraries, gamemode, mangohud                |
| sunshine        | Sunshine .deb, config, apps, user service                    |
| caddy           | reverse proxy with HTTPS (Let's Encrypt, DNS challenge), one site file per service; pulled in by the web service roles |
| jellyfin        | Jellyfin compose stack, GPU node; wizard, libraries, users via Application Programming Interface (API) |
| forgejo         | Forgejo compose stack (sqlite, closed registration, admin and users) |
| samba           | SMB shares of the mounted media datasets                     |
| mealie          | Mealie behind a Caddy proxy that signs the LAN in as one shared account; admin takeover, accounts and public access via API |
| pihole          | Pi-hole compose stack with local records from the inventory, admin UI behind Caddy; frees port 53 from systemd-resolved |
| wireguard       | wg-easy compose stack: WireGuard with a web UI behind Caddy; carries an existing wg-easy's clients over |

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

* **pi1** (10.0.1.100)
  * 22/tcp: SSH
  * 53/tcp, 53/udp: DNS
  * 443/tcp: Pi-hole admin UI and API, and the wg-easy UI, through Caddy
  * 51820/udp: WireGuard, the only port forwarded by the router
* **dns** (10.0.1.101)
  * 22/tcp: SSH
  * 53/tcp, 53/udp: DNS
  * 443/tcp: Pi-hole admin UI and API, through Caddy
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
  * 47990/tcp: Sunshine web UI (Hypertext Transfer Protocol Secure (HTTPS), first pairing)
  * 47984/tcp, 47989/tcp: Sunshine pairing and control (Moonlight)
  * 48010/tcp: Sunshine Real-Time Streaming Protocol (RTSP)
  * 47998-48000/udp: Sunshine video, control and audio streams
* **srv1** (10.0.1.200), the Proxmox host
  * 22/tcp: SSH
  * 8006/tcp: Proxmox web UI and API (HTTPS, its own certificate)

</details>

**Disclaimer.** Much of the code and documentation in this repository was
generated with Artificial Intelligence (AI) assistance and then reviewed, tested and adjusted by hand.

</details>