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

Ansible for my homelab: a Proxmox host and the VMs on it. Each VM runs one or
more services:

* **arcade**: media and game streaming, with the host's GPU passed through
  * Jellyfin: media server with hardware transcoding
  * Steam: game library
  * Sunshine: streams the desktop and games to Moonlight clients
* **forgejo-git**: code hosting
  * Forgejo: Git forge with web UI and SSH access
* **nas**: network share of the media library, for filling it from a laptop
  * Samba: SMB shares of the movies, series and music datasets

<details>
<summary style="margin-top:2.5em; border-bottom:1px solid rgba(128,128,128,.4); padding-bottom:.3em"><h2 id="prerequisites" style="display:inline; border-bottom:none; margin:0; vertical-align:middle">Prerequisites</h2></summary>

This section contains the prerequisites for setting up the complete ansible
playbook as described in [Full Setup](#full-setup). If you only want to set
up certain VMs, follow the instructions at
[Set up only select VMs](#set-up-only-select-vms).

**Host Hardware**
* A host running Proxmox VE (I have Proxmox VE 9.2.*)
* A CPU and board that support an IOMMU (Intel VT-d or AMD-Vi).
* Empty disks for the ZFS pool, two for a mirror (RAID1).
* A GPU the host can spare.

**Host BIOS**
* Virtualisation enabled (Intel VT-x or AMD-V).
* IOMMU enabled (Intel VT-d or AMD-Vi).

**Access**
* Root SSH access on the Proxmox host. We have several roles for configuration
  of the proxmox host, including setting up GPU passthrough, storage pools,
  cloud-init templates, and VMs. This requires shell access on the host.
* Physical access to the host to power cycle it once.

**Inventory**
* `host_vars/srv1.yml`: `ansible_host`, `pve_storage_pools`,
  `pve_passthrough_devices`
* `group_vars/proxmox.yml`: `pve_template_ssh_keys`, `pve_vms_gateway`
* `host_vars/<vm>.yml` per VM: `ansible_host`, `pve_vm`
* `group_vars/gaming.yml`: `desktop_force_connector`

**Your machine**
* ansible-core, or Docker.

</details>

<details>
<summary style="margin-top:2.5em; border-bottom:1px solid rgba(128,128,128,.4); padding-bottom:.3em"><h2 id="full-setup" style="display:inline; border-bottom:none; margin:0; vertical-align:middle">Full Setup</h2></summary>

You can run the Ansible playbooks from `ansible/` if you have ansible-core
installed. Alternatively, if you have docker installed, you can run it from the
docker image in `ansible/docker/runtime/`.

(Optional) build the image and open a shell in it.
```sh
cd ansible
docker build -t ansible-runtime:local --target runtime \
  -f docker/runtime/Dockerfile .
docker run --rm -it -v "$PWD/..:/work" -w /work/ansible \
  -v "$SSH_AUTH_SOCK:/ssh-agent" -e SSH_AUTH_SOCK=/ssh-agent \
  ansible-runtime:local
```

#### Step 1: install the Galaxy dependencies

Once:

```sh
cd ansible
ansible-galaxy install -r requirements.yml
```

#### Step 2: change the variables

Change the variables in `ansible/inventory/` to yours as required by your
machine.

The encrypted values in `inventory/group_vars/` (`!vault` blocks) were made
with my personal vault password, so replace them too. Pick a vault password,
then per secret:

```sh
ansible-vault encrypt_string --ask-vault-pass --stdin-name forgejo_admin_password
```

Type the value, press Ctrl-D, and paste the output over the old block in the
same file.

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

Disclaimer: this has been tested with an AMD Radeon R9 380X (Tonga), which
has no function-level reset and needs this step. I don't know how this
will work for other GPUs.

#### Step 5: set up the VMs

```sh
ansible-playbook playbooks/site.yml --limit vms --ask-vault-pass
```

The vault password is needed whenever a play touches an encrypted value from
the inventory. To avoid the prompt, keep the password in a file outside the
repo and export `ANSIBLE_VAULT_PASSWORD_FILE=<path>` instead.

</details>

<details>
<summary style="margin-top:2.5em; border-bottom:1px solid rgba(128,128,128,.4); padding-bottom:.3em"><h2 id="set-up-only-select-vms" style="display:inline; border-bottom:none; margin:0; vertical-align:middle">Set up only select VMs</h2></summary>

Every VM needs the [Proxmox host](#proxmox-host) set up first. Each VM is a
host in `inventory/hosts.yml`, with `host_vars/<vm>.yml` describing the
machine:
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
      GPU's PCI functions, from `lspci -D`. Leave empty to skip passthrough
  
  `group_vars/proxmox.yml`
    * `pve_template_ssh_keys`: public keys that may log in to the VMs
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

* Attach a dummy HDMI plug or set `desktop_force_connector`.
* Replace the placeholder `jellyfin_admin_password` in `group_vars/jellyfin.yml`
  with a `!vault` value (see Secrets). The role runs Jellyfin's setup wizard
  with it: admin user, libraries from `jellyfin_libraries`, hardware
  transcoding. Leave it empty to do the wizard in the browser instead.
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
uid, so they show up in the library on the next scan.

</details>

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
│   │   └── host_vars/       per machine 'physical' settings: IP address and 
|   |                        hardware (PCI devices, disks, CPU cores, memory)
|   |
│   ├── playbooks/site.yml   maps groups to roles
│   ├── roles/               one role per service or building block
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

In the order the playbook runs them.

| Role            | Purpose                                                      |
|-----------------|--------------------------------------------------------------|
| pve_passthrough | Proxmox host: IOMMU, vfio binding, driver blacklist, console |
| pve_storage     | Proxmox host: ZFS pools, datasets, virtiofs mappings         |
| pve_template    | Proxmox host: Ubuntu cloud-init template VMs are cloned from |
| pve_vms         | Proxmox host: clones and reconciles the VMs in the inventory |
| base            | guest agent, unattended upgrades, timezone                   |
| shares          | mounts the VM's virtiofs shares from `pve_vm.shares`         |
| gpu             | firmware, userspace and i386 packages for `gpu_vendors`      |
| desktop         | Xorg + LightDM autologin + openbox session for `gamer`       |
| steam           | Steam with i386 libraries, gamemode, mangohud                |
| sunshine        | Sunshine .deb, config, apps, user service                    |
| jellyfin        | Jellyfin compose stack, GPU render node, wizard via API      |
| forgejo         | Forgejo compose stack (sqlite, closed registration, admin)   |
| samba           | SMB shares of the mounted media datasets                     |

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
| jellyfin | Docker engine inside the instance; the compose stack really starts |
| forgejo  | as jellyfin; also checks health, API and the admin account   |
| samba    | real smbd; lists the share and writes a file through it       |

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
  * SSD: Lexar NQ780 1 TB M.2 2280 PCIe 4.0 x4 NVMe
  * HDD: 2x Seagate IronWolf 8 TB (ST8000VN004-2M2101)

</details>

<details>
<summary><strong>Ports</strong></summary>

* **arcade** (10.0.1.160)
  * 22/tcp: SSH
  * 8096/tcp: Jellyfin web UI and API
  * 7359/udp: Jellyfin client auto-discovery
  * 1900/udp: Jellyfin DLNA
  * 47990/tcp: Sunshine web UI (HTTPS, first pairing)
  * 47984/tcp, 47989/tcp: Sunshine pairing and control (Moonlight)
  * 48010/tcp: Sunshine RTSP
  * 47998-48000/udp: Sunshine video, control and audio streams
* **forgejo-git** (10.0.1.110)
  * 22/tcp: SSH to the VM
  * 3000/tcp: Forgejo web UI and HTTP clone
  * 2222/tcp: Forgejo SSH clone
* **nas** (10.0.1.120)
  * 22/tcp: SSH
  * 445/tcp: SMB shares

</details>

**Disclaimer.** Much of the code and documentation in this repository was
generated with AI assistance and then reviewed, tested and adjusted by hand.

</details>