# Instructions for AI agents

All Ansible lives under `ansible/`; run `ansible-*` and `molecule` commands
from that directory. Terraform for the Proxmox host is planned as a sibling
`terraform/` directory with its own images and lint.

Guidance for automated changes to this repository. Humans are welcome to read
it, but the README is written for them.

## Dependency pinning

Every external input must be immutable. Never introduce a floating reference,
and when touching a pin, update the pin and its comment in the same change.

| Kind | Pin | Comment beside it |
|---|---|---|
| Container image | `name@sha256:…` (no tag in the reference) | `name:tag -- digest pushed YYYY-MM-DD HH:MM UTC` |
| GitHub action | full commit SHA | `# vX.Y.Z` |
| Galaxy role | git `src` + `scm: git` + commit SHA as `version` | `# X.Y.Z` |
| Galaxy collection | exact `version:` | none needed; published versions are immutable |
| Python package | exact `==` version, transitives included | grouped and annotated as in `ansible/docker/*/requirements*.txt` |
| Downloaded file | `checksum: sha256:…` on the download task | the release it came from |
| GitHub runner | `ubuntu-XX.04`, never `ubuntu-latest` | none |

A tag next to a digest is documentation only: Docker ignores it and applies
no check. That is why tags go in the comment, not in the reference.

### Resolving a pin

Container image digest and push time:

```sh
docker buildx imagetools inspect <name>:<tag> | grep Digest
docker buildx imagetools inspect --format '{{range $k,$v := .Image}}{{$k}} {{$v.Created}}{{"\n"}}{{end}}' <name>@sha256:…
```

Use the `linux/amd64` timestamp. Base image digests in Dockerfiles follow the
same comment form.

GitHub action or Galaxy role commit for a tag:

```sh
git ls-remote https://github.com/<owner>/<repo> refs/tags/<tag> 'refs/tags/<tag>^{}'
```

A peeled `^{}` line means the tag is annotated; use that SHA. No peeled line
means the tag is lightweight and the first SHA is the commit.

Downloaded file checksum, after confirming the response is the real file and
not an error page (check `content-length` or the size):

```sh
curl -sL <url> | sha256sum
```

### Deliberately not pinned

apt packages installed on the VMs. Ubuntu's archive moves with security
updates and unattended-upgrades is enabled on purpose.

### Bumping

One commit per bump, or one per related group. Resolve the new digest or
commit as above, update the comment with the new tag and date, and let CI
rebuild the images; their tags are content hashes so nothing else changes.

## Secrets

Never write a plaintext secret into the repository. A secret is an inline
`!vault` value produced by `ansible-vault encrypt_string --name <variable>`,
placed in the group or host vars file under `ansible/inventory/` where the
setting belongs (a Forgejo password goes in `group_vars/forgejo.yml`, not
`group_vars/all.yml`). Do not
create fully encrypted vars files: they cannot be parsed without the password
and break lint and CI. Do not add `vault_password_file` to `ansible.cfg` for
the same reason; the password comes from `ANSIBLE_VAULT_PASSWORD_FILE`.
Tasks that handle a secret carry `no_log: true`.
