# Instructions for AI agents

All Ansible lives under `ansible/`; run `ansible-*` and `molecule` commands
from that directory. Terraform lives under `terraform/`: one stack per
purpose under `stacks/` (`dns`, `minecraft`), each with its own state,
pins and lock file, and shared building blocks under `modules/`. A stack
is named after what it is for, never after a provider; a new purpose is a
new stack, and a stack reads what another owns through a data source, not
through its state. Terraform for the Proxmox host is planned as another
stack. Terraform has no lint or image in CI yet: run
`terraform fmt -check -recursive` and `terraform validate` by hand.

Guidance for automated changes to this repository. Humans are welcome to read
it, but the README is written for them.

## Dependency pinning

Every external input must be immutable. Never introduce a floating reference,
and when touching a pin, update the pin and its comment in the same change.

| Kind | Pin | Comment beside it |
|---|---|---|
| Base image in a Dockerfile | `FROM name:tag@sha256:…` | none; Dependabot moves tag and digest together |
| Container image in Ansible vars | `name:tag@sha256:…`, as a folded scalar (`>-`) to keep lines short | none |
| GitHub action | full commit SHA | `# vX.Y.Z` |
| Galaxy role | git `src` + `scm: git` + commit SHA as `version` | `# X.Y.Z` |
| Galaxy collection | exact `version:` | none needed; published versions are immutable |
| Python package | exact `==` version, transitives included | grouped and annotated as in `ansible/docker/*/requirements*.txt` |
| Downloaded file | `checksum: sha256:…` on the download task | the release it came from |
| GitHub runner | `ubuntu-XX.04`, never `ubuntu-latest` | none |
| Terraform and its providers | exact `required_version` and `version`, no `~>` or `>=`; commit `.terraform.lock.hcl` | none; the lock file holds the checksums |

A tag next to a digest is documentation only: Docker ignores it and applies
no check. It is written anyway, in the `name:tag@sha256:…` form, because
update tools read the tag to find newer versions: Dependabot does so on
`FROM` lines (with a digest alone it would follow `latest`, and it does not
read `FROM ${ARG}` at all), and Renovate, if it is added, would do the
same for the Ansible vars.

### Resolving a pin

Container image digest:

```sh
docker buildx imagetools inspect <name>:<tag> | grep Digest
```

GitHub action or Galaxy role commit for a tag:

```sh
git ls-remote https://github.com/<owner>/<repo> refs/tags/<tag> 'refs/tags/<tag>^{}'
```

A peeled `^{}` line means the tag is annotated; use that SHA. No peeled line
means the tag is lightweight and the first SHA is the commit.

Terraform provider checksums, after changing a version in `versions.tf`,
for every platform the configuration is run on:

```sh
terraform providers lock -platform=darwin_arm64 -platform=linux_amd64 -platform=linux_arm64
```

Downloaded file checksum, after confirming the response is the real file and
not an error page (check `content-length` or the size):

```sh
curl -sL <url> | sha256sum
```

### Deliberately not pinned

apt packages installed on the VMs. Ubuntu's archive moves with security
updates and unattended-upgrades is enabled on purpose.

The Minecraft server and Fabric loader jars have an exact version but no
checksum here: the pinned `itzg/minecraft-server` image downloads them on
its first start and checks them against Mojang's and Fabric's own hashes.
The mods are ordinary downloaded files, with a checksum each.

### Bumping

Dependabot (`.github/dependabot.yml`) proposes updates for GitHub actions,
Python packages and Dockerfile base images once a release is two days old.
Everything else is bumped by hand: one commit per bump, or one per related
group. Resolve the new digest or commit as above, update the version
comment where there is one, and let CI rebuild the images; their tags are
content hashes so nothing else changes.

## Replies

When you give the user commands to run, put each command in its own code
block, so it can be copied on its own. A single command that continues over
several lines stays in one block.

## Secrets

Never write a plaintext secret into the repository. A secret is an inline
`!vault` value produced by `ansible-vault encrypt_string --name <variable>`,
placed in the group or host vars file under `ansible/inventory/` where the
setting belongs (a Forgejo password goes in `group_vars/forgejo.yml`, not
`group_vars/all.yml`). Do not
create fully encrypted vars files: they cannot be parsed without the password
and break lint and CI. Do not add `vault_password_file` to `ansible.cfg` for
the same reason; runs take `--ask-vault-pass` or `ANSIBLE_VAULT_PASSWORD_FILE`.
Tasks that handle a secret carry `no_log: true`. Terraform's secrets are
in `terraform/secrets/*.sops.yaml`, encrypted with SOPS for the age keys
in `terraform/.sops.yaml`; never write one in plain text, and add a key
to the matching `.example.yaml` when adding one. Credentials are read
with an `ephemeral "sops_file"` block, so they stay out of the state; a
`data "sops_file"` is only for a value that ends up in a resource anyway.
`terraform.tfvars` is committed and holds settings only, and state files
are never committed. The domain and the public address of the home
network are secrets too, because they say whose homelab this is: outside
the encrypted values they never appear in the repository, in any form.
Write `<domain>` or `example.org`, and an address from `203.0.113.0/24`,
in documentation, comments and examples. Placeholders for secrets
are vaulted too, encrypted with a throwaway password, so a run that still
carries one fails to decrypt instead of applying a known value.

## Comments and documentation

A comment documents the lines below it, in that file, and nothing else. How
a feature works across the system belongs in the README or next to the
variable in the role's `defaults/main.yml`, not in a template or an
inventory file. One or two lines is the norm.

Anything the maintainer has to do goes in its own `# TODO: ...` line, kept
apart from the comment that documents the setting:

```yaml
# Sent by the Caddy proxy with every request. Any long random string.
# TODO: replace with your own !vault value; this one will not decrypt.
mealie_proxy_secret: !vault |
```

The README is written for other people who clone the repository. The
vaulted values in `inventory/` are the maintainer's own secrets, so the
per-VM sections say "replace the encrypted X with your own (see Secrets)"
and never call them placeholders. Write what a reader does and what is
true afterwards, in everyday words, and leave out anything that only
restates what a role obviously does. A note in a table that says nothing a
newcomer can act on is removed rather than reworded.
