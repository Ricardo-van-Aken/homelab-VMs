# Instructions for AI agents

All Ansible lives under `ansible/`; run `ansible-*` and `molecule` commands
from that directory. OpenTofu (`tofu`, never `terraform`) lives under
`terraform/`.

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
| Downloaded file | `checksum: sha256:…` on the download task, or checked with `sha256sum -c` in a Dockerfile | the release it came from |
| GitHub runner | `ubuntu-XX.04`, never `ubuntu-latest` | none |
| OpenTofu and its providers | exact `required_version` and `version`, no `~>` or `>=`; commit `.terraform.lock.hcl` | none; the lock file holds the checksums |

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

OpenTofu provider checksums, after changing a version in `versions.tf`,
for every platform the configuration is run on:

```sh
tofu providers lock -platform=darwin_arm64 -platform=linux_amd64 -platform=linux_arm64
```

Downloaded file checksum, after confirming the response is the real file and
not an error page (check `content-length` or the size):

```sh
curl -sL <url> | sha256sum
```

### Deliberately not pinned

apt packages installed on the VMs. Ubuntu's archive moves with security
updates and unattended-upgrades is enabled on purpose.

The Minecraft server and Fabric loader jars: an exact version, but no
checksum. The pinned image downloads them and checks Mojang's own hashes.

### Bumping

Dependabot (`.github/dependabot.yml`) proposes updates for GitHub actions,
Python packages and Dockerfile base images once a release is two days old.
Everything else is bumped by hand: one commit per bump, or one per related
group. Resolve the new digest or commit as above, update the version
comment where there is one, and let CI rebuild the images; their tags are
content hashes so nothing else changes.

## OpenTofu

* One stack per purpose under `terraform/stacks/`, each with its own state
  and lock file. Name a stack after what it is for, never after a provider.
* A stack reads what another stack owns through a data source, not through
  its state.
* A value Ansible also has is read from the Ansible inventory by path,
  never copied. A `main.yml` read this way stays plain YAML, without tagged
  values such as `!unsafe`.
* Read credentials with `ephemeral "sops_file"`, so they stay out of the
  state. `data "sops_file"` writes the whole file into the state: use it
  only for `identity.sops.yaml`.
* `terraform.tfvars` holds settings only and is committed. State files are
  never committed.
* There is no OpenTofu lint in CI yet: run `tofu fmt -check
  -recursive` and `tofu validate` in each stack.

## Replies

When you give the user commands to run, put each command in its own code
block, so it can be copied on its own. A single command that continues over
several lines stays in one block.

## Secrets

Never write a plaintext secret into the repository. Secrets are encrypted
with SOPS, and you have no key: name the file and the variable, and leave
writing it to the maintainer (`sops edit <file>`).

| Secret | File |
|---|---|
| of a group or host | `secrets.sops.yaml` in its directory under `ansible/inventory/group_vars/` or `host_vars/` |
| the domain and the home's public address | `group_vars/all/identity.sops.yaml`, which holds nothing else |
| only OpenTofu needs | `terraform/secrets/*.sops.yaml`, with its keys in the `.example.yaml` beside it |

* A group or host gets a directory with its first secret: `<name>.yml`
  becomes `<name>/main.yml`.
* Comments in a SOPS file are encrypted too. So each key has an entry in
  the `main.yml` beside it, and a row in `docs/secrets.md`:

  ```yaml
  # Password for the admin UI.
  # SECRET: in secrets.sops.yaml.
  # pihole_web_password: <string>
  ```

* The domain and the home address appear nowhere else. In documentation
  and examples, write `<domain>` or `example.org`, and `203.0.113.7`.
* Tasks that handle a secret carry `no_log: true`.

## Comments and documentation

A comment documents the lines below it, in that file, and nothing else. How
a feature works across the system belongs in the README or next to the
variable in the role's `defaults/main.yml`, not in a template or an
inventory file. One or two lines is the norm.

Anything the maintainer has to do goes in its own `# TODO: ...` line, kept
apart from the comment that documents the setting:

```yaml
# Mojang's End User License Agreement, https://aka.ms/MinecraftEULA.
# TODO: read it and set to true to agree; the role stops while it is false.
minecraft_eula: false
```

The README is written for other people who clone the repository. The
encrypted files in `inventory/` are the maintainer's own secrets, so the
per-VM sections say "replace the encrypted X in `<file>` with your own (see
Secrets)" and never call them placeholders. Write what a reader does and what is
true afterwards, in everyday words, and leave out anything that only
restates what a role obviously does. A note in a table that says nothing a
newcomer can act on is removed rather than reworded.

Keep all documentation concise. In the README, a machine's section says
what it is, what to set and the command to run, in about twenty lines. How
to operate a service, other ways to run it, and tools with a procedure of
their own go in `docs/<topic>.md`, linked from the README in one sentence
and not repeated there.
