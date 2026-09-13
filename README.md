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

Ansible for the VMs in my homelab. Each VM runs one or more services.


## Usage

Locally, with ansible-core installed:

```sh
ansible-galaxy install -r requirements.yml
ansible-playbook playbooks/site.yml
```

Or from the runtime image, which carries ansible-core and the Galaxy
dependencies:

```sh
docker run --rm -it \
  -v "$PWD:/work:ro" \
  -v "$SSH_AUTH_SOCK:/ssh-agent" -e SSH_AUTH_SOCK=/ssh-agent \
  ghcr.io/ricardo-van-aken/homelab-vms/ansible-runtime:<tag> \
  ansible-playbook playbooks/site.yml
```

## Layout

```
.
├── AGENTS.md              rules for AI agents (dependency pinning); CLAUDE.md imports it
├── ansible.cfg            inventory, role and collection search paths
├── requirements.yml       Galaxy roles and collections, exact pins
├── inventory/
│   ├── hosts.yml          one group per service, VMs join what they host
│   ├── group_vars/        settings per service group
│   └── host_vars/         settings per VM
├── playbooks/
│   └── site.yml           maps groups to roles
├── roles/                 one role per service or building block
├── molecule/              one test scenario per container-testable role
├── .config/molecule/      settings shared by every scenario
├── docker/
│   ├── analysis/          image for lint and syntax check (CI)
│   ├── molecule-target/   Ubuntu 26.04 + systemd, the VM stand-in for tests
│   └── runtime/           image for applying playbooks; molecule stage for tests
├── .github/
│   └── workflows/         analysis, molecule, and the shared image build
└── galaxy_roles/          external roles installed locally (gitignored)
```

### Own roles

| Role     | Purpose                                                      |
|----------|--------------------------------------------------------------|
| base     | guest agent, unattended upgrades, timezone                   |
| gpu      | vendor userspace packages, render group id (`gpu_vendor`)    |
| desktop  | Xorg + LightDM autologin + openbox session for `gamer`       |
| steam    | Steam with i386 libraries, gamemode, mangohud                |
| sunshine | Sunshine .deb, config, apps, user service                    |
| jellyfin | Jellyfin compose stack with GPU render node                  |
| forgejo  | Forgejo compose stack (sqlite, closed registration, admin)   |

### External roles

Pinned in `requirements.yml`, installed to `galaxy_roles/` locally and baked
into the container images.

| Role               | Purpose                            |
|--------------------|------------------------------------|
| geerlingguy.docker | Docker engine and compose plugin   |

## Testing

Roles that can run in a container have a Molecule scenario under `molecule/`;
shared settings live in `.config/molecule/config.yml`. Instances are
containers from `docker/molecule-target`: Ubuntu 26.04 with systemd and
python3, the same release as the VMs. Build it once, then run a scenario from
the molecule image with the socket mounted:

```sh
docker build -t molecule-target:local docker/molecule-target
docker run --rm -it --user root -v "$PWD:/work" \
  -v /var/run/docker.sock:/var/run/docker.sock \
  ghcr.io/ricardo-van-aken/homelab-vms/ansible-molecule:<tag> \
  molecule test --scenario-name base
```

| Scenario | Notes                                                        |
|----------|--------------------------------------------------------------|
| base     |                                                              |
| gpu      | package-level checks; no GPU in the instance                 |
| steam    | needs an amd64 host (i386 packages)                          |
| jellyfin | Docker inside the instance; the compose stack really starts  |
| forgejo  | as jellyfin; also checks health, API and the admin account   |

`desktop` and `sunshine` need a display stack and a user session, which a
container cannot provide. They are validated on a VM.

## VMs

One subsection per VM. Each VM joins the inventory groups of the services it
hosts; the sections describe what is specific to that machine.

### arcade

Runs Jellyfin, Steam and Sunshine on one VM with a passed-through GPU.

* Set `gpu_vendor` in host_vars (`amd`, `intel`, `nvidia`). Vendor packages
  live in `roles/gpu/vars/`; everything else is vendor-neutral.
* Headless: attach a dummy HDMI plug, or set `desktop_force_connector` to the
  DRM connector name (see `ls /sys/class/drm`) so Xorg finds a screen.
* Sunshine ships one `.deb` per Ubuntu series and architecture. The role
  refuses any asset without a sha256 in `sunshine_deb_checksums`; add an entry
  when targeting a new series or architecture.
* First Sunshine pairing: open `https://arcade:47990` from the LAN and set a
  password, then pair the Moonlight client.
* Jellyfin reads media from `jellyfin_media_path`; mount it before running.

### forge

Runs Forgejo from `/opt/stacks/forgejo`. HTTP on 3000, SSH on 2222 so the
VM's own sshd keeps 22. Registration is closed; set `forgejo_admin_password`
in a vault to have the first admin created, or create one afterwards:

```sh
docker exec --user git forgejo forgejo admin user create --admin \
  --username admin --email admin@forge.lan --password '...'
```