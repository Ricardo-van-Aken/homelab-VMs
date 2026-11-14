# Cloud resources

What is rented outside the house is made with
[Terraform](https://developer.hashicorp.com/terraform/install) 1.17.2,
under `terraform/`. It is split into stacks, one per purpose. Each stack
keeps its own record of what it made, so working on one cannot change
another.

| Stack | Makes |
|---|---|
| `stacks/dns` | the domain's Domain Name System (DNS) zone at Hetzner, taken over as it is, and the records kept by hand |
| `stacks/minecraft` | the bucket for the Minecraft backups, and two servers, each with its firewall and its name under the domain: the relay and the standby ([Minecraft](minecraft.md)) |

## Before the first run

Terraform takes what it shares with Ansible from the Ansible inventory, so
nothing is kept twice: the domain and your home's public address, the S3
credentials, the SSH keys, and the servers' names and ports. Make the
secret files first ([secrets](secrets.md)).

In the [Hetzner console](https://console.hetzner.com), in the project that
holds the zone, make:

* S3 credentials (Security, S3 credentials), for
  `group_vars/minecraft/secrets.sops.yaml`;
* an Application Programming Interface (API) token with read and write
  access (Security, API tokens), the one secret only Terraform needs:

```sh
sops edit terraform/secrets/credentials.sops.yaml
```

Terraform logs in with the token and the S3 credentials and never writes
them down.

## Run a stack

From the repository's root, the `dns` stack first:

```sh
terraform -chdir=terraform/stacks/dns init
```

```sh
terraform -chdir=terraform/stacks/dns plan
```

Read the plan before going on. The zone and the `wg-easy` record exist
already and are taken over (imported), so the plan should change little
about them and destroy nothing. Records that are in no stack are left
alone; to manage another one, add it to the stack's `main.tf` with an
`import` block like the ones there.

```sh
terraform -chdir=terraform/stacks/dns apply
```

The `minecraft` stack is run the same way. In its `terraform.tfvars`, set
`backup_bucket`, and `relay_server` and `standby_server` to say which of
the two servers exist; both at once is fine. It prints the
`backup_repository` to put in `minecraft_backup_repository`.

## Keep the state

Each stack keeps what it made in a `terraform.tfstate` file next to its
code, out of git. Keep those files, and keep them to yourself: without
one, Terraform no longer knows what is its own, and it holds your domain
and home address in plain text.

## Add something

For something new, a bucket for photo backups for example, add a stack
beside these two. `modules/backup-bucket` is a bucket that Terraform can
never empty or remove.
