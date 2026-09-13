# homelab-VMs

Ansible for the VMs in my homelab. Each VM runs one or more services; a VM
joins one inventory group per service it hosts.

## Layout

```
inventory/           hosts, group_vars (service groups), host_vars (per VM)
playbooks/site.yml   maps groups to roles
roles/               one role per service or building block
requirements.yml     Galaxy roles and collections
```

| Role         | Purpose                                                       |
|--------------|---------------------------------------------------------------|
| base         | guest agent, unattended upgrades, timezone                    |
| gpu          | vendor userspace packages, render group id (`gpu_vendor`)     |
| desktop      | Xorg + LightDM autologin + openbox session for `gamer`        |
| steam        | Steam with i386 libraries, gamemode, mangohud                 |
| sunshine     | Sunshine .deb, config, apps, user service                     |
| jellyfin     | Jellyfin compose stack with GPU render node                   |
| geerlingguy.docker | Docker engine and compose plugin (Galaxy)                |

## Usage

Locally, with ansible-core installed:

```sh
ansible-galaxy install -r requirements.yml
ansible-playbook playbooks/site.yml
```

Or from the runtime image, which carries ansible-core and the Galaxy
dependencies. The project is mounted read-only and the ssh agent is forwarded,
so no key file enters the container and host file ownership does not matter:

```sh
docker run --rm -it \
  -v "$PWD:/work:ro" \
  -v "$SSH_AUTH_SOCK:/ssh-agent" -e SSH_AUTH_SOCK=/ssh-agent \
  ghcr.io/ricardo-van-aken/homelab-vms/ansible-runtime:<tag> \
  ansible-playbook playbooks/site.yml
```

## Container images

`docker/analysis` (lint, CI) and `docker/runtime` (apply, molecule) are built
from the repo root. The image tag is a hash over the git object ids of every
input path (`hash_paths` in the workflow), and the root `.dockerignore` is an
allowlist of the same paths, so a build can never read a file the tag does not
cover. Galaxy roles and collections are baked in from `requirements.yml`; the
Ansible project itself is mounted at run time. A self-contained image with the
project copied in can be added later as an extra stage.

## The `arcade` VM

Runs Jellyfin, Steam and Sunshine on one VM with a passed-through GPU.

* Set `gpu_vendor` in host_vars (`amd`, `intel`, `nvidia`). Vendor packages
  live in `roles/gpu/vars/`; everything else is vendor-neutral.
* Headless: attach a dummy HDMI plug, or set `desktop_force_connector` to the
  DRM connector name (see `ls /sys/class/drm`) so Xorg finds a screen.
* Sunshine ships one `.deb` per Ubuntu series. If there is no asset for the
  running series yet, override `sunshine_ubuntu_release` or `sunshine_deb_url`.
* First Sunshine pairing: open `https://arcade:47990` from the LAN and set a
  password, then pair the Moonlight client.
* Jellyfin reads media from `jellyfin_media_path`; mount it before running.
