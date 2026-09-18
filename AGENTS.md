# AGENTS.md

Canonical project instructions for coding agents working in this Terraform monorepo. Keep this file aligned with tracked configuration; platform READMEs provide usage examples. Project-specific conventions take precedence over generic plugin guidance.

## Repository layout

Five platforms sharing the same three-layer architecture:

```
<platform>/modules/<name>/       # Reusable submodule: main.tf + variables.tf + outputs.tf + versions.tf
<platform>/_shared/              # variables.tf, outputs.tf (symlinked into each env)
<platform>/envs/<env>/           # One dir per env: provider + backend + root module call
<platform>/main.tf               # Root module — wires submodules
```

**GCP** (8 modules), **AWS** (6), **Proxmox** (3), **OpenStack** (3), **Vultr** (2).

| Platform | Modules and responsibilities | Tracked environments |
|---|---|---|
| GCP | `network` VPC/subnets/firewalls; `nat` routers/Cloud NAT; `iam` service accounts and memberships; `storage` buckets; `compute` VMs/disks/instance groups; `lb` instance-group ALB; `neg-lb` existing NEG-backed ALB; `gke` clusters/node pools | `dev`, `base` |
| AWS | `network` VPC/routing/SGs; `iam` roles/profiles/users; `compute` EC2/key pairs/EIPs; `rds` databases/passwords; `lambda` archives/functions/URLs; `budget` budgets/notifications | `dev`, `logic3579` |
| Proxmox | `network` Linux bridges; `storage` image/ISO/template downloads; `compute` KVM VMs/cloud-init | `dev` |
| OpenStack | `network` Neutron networks/routers/SGs/floating IPs; `storage` Cinder volumes; `compute` instances/keypairs | `dev` |
| Vultr | `network` VPC/firewall groups/rules; `compute` instances/SSH keys/startup scripts | `logic3579` |

This repository consumes providers; it does not implement Terraform providers in Go.

## Critical: symlinks — do NOT edit in env dirs

Every `envs/<env>/variables.tf` and `envs/<env>/outputs.tf` is a **symlink** to `../../_shared/`. The only files you edit in an env dir are:
- `main.tf` (provider/backend/module call — NOT symlinked)
- `terraform.tfvars` (gitignored)
- `backend.hcl` (gitignored)

Edit shared files through `<platform>/_shared/`. Writing through a symlink may change its shared target; replacement-style edits may replace the link itself. Preserve both the shared contract and the links. `gcp/_shared/main.tf` and `providers.tf` are auxiliary templates, not the tracked environment entrypoints; the main template does not forward every current input.

## .gitignore — what's never committed

`*.tfvars`, `*.tfvars.json`, `*.tfstate`, `*.tfstate.*`, `**/keys/`, `.terraform/`, and **`**/backend.hcl`** (credentials). Generic `*.json` files are NOT ignored. Reference templates live directly in `<platform>/envs/`. Provider lockfiles (`.terraform.lock.hcl`) are tracked; preserve them. Saved plan files are not currently ignored, so do not commit them.

## Per-platform operational commands

Run init/validate/plan/apply from the target env directory. Run repository-wide formatting checks from the repository root. Each platform has auth/backend quirks:

| Platform | Init | Backend | Auth note |
|---|---|---|---|
| GCP | `terraform init -backend-config=backend.hcl` | GCS | Both `google` AND `google-beta` providers required |
| AWS | `terraform init -backend-config=backend.hcl` | S3 (or R2) | IAM Identity Center SSO — run `aws sso login --profile <name>` first |
| Proxmox | `terraform init` (no backend args) | Local | `bpg/proxmox` pinned to `~> 0.104.0` — DO NOT BUMP (v0.105 schema bug) |
| OpenStack | `terraform init -backend-config=backend.hcl` | S3 via Swift | Export `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY` (Swift EC2 creds) |
| Vultr | `terraform init` (no backend args) | Local | `VULTR_API_KEY` env var only; do NOT set `api_key` in tfvars |

## Provider version pins (do NOT bump blindly)

- `bpg/proxmox` `~> 0.104.0` — v0.105+ breaks `proxmox_virtual_environment_network_linux_bridge` on `ports` attribute
- GCP uses **both** `hashicorp/google` and `hashicorp/google-beta` `~> 7.0` — the GKE module exclusively uses `google-beta` resources
- OpenStack state uses S3 backend pointed at Swift because the native `swift` backend was removed in Terraform 1.3
- AWS Lambda module requires the `hashicorp/archive` provider; AWS RDS module requires `hashicorp/random`
- Root Terraform constraint is `~> 1.5` (>= 1.5, < 2.0, not restricted to 1.5.x). AWS is `~> 5.0`, OpenStack `~> 3.4`, Vultr `~> 2.31`. Check module and environment constraints as well as root constraints before changing dependencies.

## Verification workflow

Use `rtk` for shell commands; `rtk proxy <command>` preserves raw output for unsupported commands.

```bash
# From repository root
rtk proxy terraform fmt -check -recursive

# From the affected environment, after provider/module installation
rtk proxy terraform validate
```

For configuration validation without initializing remote state, use `rtk proxy terraform init -backend=false` in a clean temporary copy of the affected platform (preserve symlinks, omit credentials/state and `.terraform/`), then validate its env. This still downloads providers/modules; it does not switch an existing remote backend to local state. A plan needs the actual configured backend and authentication. Report which checks ran and any missing prerequisites; documentation-only edits need link/diff checks, not a cloud plan.

## Adding a new environment

```bash
# From repository root; choose a tracked source env from the table above.
# Copy only configuration, never a working env's state/cache/credentials.
rtk proxy mkdir <platform>/envs/<new-env>
rtk proxy cp <platform>/envs/<source-env>/main.tf <platform>/envs/<new-env>/main.tf
rtk proxy ln -s ../../_shared/variables.tf <platform>/envs/<new-env>/variables.tf
rtk proxy ln -s ../../_shared/outputs.tf <platform>/envs/<new-env>/outputs.tf
rtk proxy cp <platform>/envs/terraform.tfvars.example <platform>/envs/<new-env>/terraform.tfvars
# Remote-backend platforms only: GCP, AWS, OpenStack
rtk proxy cp <platform>/envs/backend.hcl.example <platform>/envs/<new-env>/backend.hcl
```

Set the new environment name, auth, and unique backend prefix/key before init. Vultr's source env is `logic3579`; it has no `dev` directory. Proxmox and Vultr have no backend.hcl template.

## State management & tfvars-sync.sh

`scripts/tfvars-sync.sh upload|download --platform X --storage s3|r2|gcs [--env Y]` syncs `terraform.tfvars` (and optionally `terraform.tfstate`) to remote object storage. Defaults: `--file terraform.tfvars`, `--bucket terraform-state`. For `--storage r2`, `--endpoint` is required and `S3_ACCESS_KEY`/`S3_SECRET_ACCESS_KEY` env vars are mandatory.

- Invoke as `rtk proxy ./scripts/tfvars-sync.sh ...` from the repository root; the script resolves envs relative to its own location.
- Omitting `--env` processes every env for the platform. `--file` selects one file per invocation; state and tfvars require separate calls. Downloads overwrite the selected local file.
- Object keys are `<platform>/<env>/<file>` for all three storage types. Use `--dry-run` to preview; R2 still requires credentials and its preview reveals the access-key prefix.
- S3 credentials fall back to the AWS default chain; GCS uses `GOOGLE_APPLICATION_CREDENTIALS` when supplied, otherwise the active gcloud account. R2 forces `--region auto`.
- GCP backend prefix convention is `gcp/<env>`; AWS/OpenStack backend key convention is `<platform>/<env>/terraform.tfstate`. Copying local state to object storage is a backup, not remote backend configuration or state locking.

## Key Terraform patterns across all platforms

### Compound-keyed maps + flatten()

Modules receive flat lists of objects with nested lists. A `locals` block uses `flatten()` to produce flat maps keyed by compound strings like `"vpc-name/subnet-name"`, then `for_each` iterates over the result. This is the universal pattern — follow it for any new module.

### `optional(type, default)` everywhere

Variable types use `optional()` extensively. All nested object attributes default to `[]`, `null`, or sensible values. Never assume an attribute is required — check the variable definition.

### Cross-module name-based references (not ID-based)

The root module threads outputs between submodules using **name maps**:
```
module.network → outputs { subnet_ids_by_name, security_group_ids_by_name }
module.iam     → outputs { ec2_instance_profile_names, lambda_role_arns }
module.compute → inputs { subnet_ids_by_name, iam_instance_profile_names }
```

LBs reference instance groups by name; the root module resolves them (GCP: locals block transforms names → self_links before passing to the LB module).

### Non-authoritative IAM only

For GCP, use `*_iam_member` (not authoritative `*_iam_binding` or `*_iam_policy`) to preserve external role assignments. AWS uses its own role/user policy attachment resources.

### Validation blocks on root variables

Put platform input validation in `<platform>/variables.tf`, with `can(regex(...))`, `contains([...])`, `alltrue()`, etc. Existing reusable modules also validate their own contracts. Propagate type/default changes through `_shared/variables.tf`, root/module variables, root wiring, every tracked env's `main.tf`, and `.example` inputs as applicable; these interfaces are not generated automatically.

### Dynamic blocks for conditionals

Resources use `dynamic` blocks for optional attributes (e.g., `dynamic "access_config"` only when `external_ip = true`). Follow this pattern — never use `count` on a nested block.

### conditional resource creation

Entire resources are created with `count = <condition> ? 1 : 0` or `for_each = <condition> ? toset([1]) : toset([])`. Check existing patterns per platform.

## Platform-specific gotchas

### GCP
- `gcp/main.tf` has a `locals` block (`load_balancers_with_self_links`) that resolves instance group names to self_links — any LB-related change must preserve this
- Firewall `firewall_attrs` local converts empty lists to null because GCP API rejects empty `source_ranges`/`source_tags`
- `cloud-init.yaml.tpl` is rendered via `templatefile()` in the compute module — changes to the template must match the variable contract in `modules/compute/`

### AWS
- SG rule resources (`aws_vpc_security_group_ingress_rule`/`_egress_rule`) only honor `cidr_blocks[0]` — split per CIDR for multi-CIDR rules
- SG rules auto-null `from_port`/`to_port` when `protocol = "-1"` (AWS rejects the combination)
- IAM module intentionally does NOT manage console passwords or access keys (cleartext in state) — document this for any IAM addition
- RDS `engine_version` is in `ignore_changes` to prevent AWS minor upgrades from triggering replacement
- `user_data` on EC2 is in `ignore_changes` (bake config into AMI or use SSM)
- The documented `logic3579` setup uses the `logic3579-admin` SSO profile and R2 backend; actual values live in ignored local files. Keep AWS provider SSO separate from R2 backend credentials. The tracked backend example only suggests `use_lockfile = true` in a comment; do not assume locking is enabled. Enabling it requires Terraform 1.10+.
- Provider `default_tags` supplies `Environment` and `ManagedBy`; env module calls pass `var.tags` without duplicating those defaults (IAM tag keys are case-insensitive).
- RDS passwords are generated with `random_password` and stored in SSM SecureString, but remain sensitive state data. Supply DB subnets across at least two AZs.
- Lambda `source_dir` is relative to `path.root` (the env directory), not the Lambda module directory.
- `aws/main.tf` supports `iam_users`, but current tracked env module calls do not forward it. Check end-to-end wiring before claiming an input works from tfvars.

### Proxmox
- Provider pinned `~> 0.104.0` — DO NOT BUMP. Network resource name is `proxmox_virtual_environment_network_linux_bridge` (will change when bumped)
- State is local in the current configuration. Back up `terraform.tfstate` via `tfvars-sync.sh --file terraform.tfstate`; shared backend adoption is a separate configuration/migration task.
- API token auth is preferred; username/password and optional SSH configuration are available. Storage downloads expose IDs, but root compute currently receives `var.vms` directly rather than automatically resolving storage output names.

### OpenStack
- State backend is S3 pointed at Swift's S3-compatible API — set `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY` to Swift EC2 credentials
- Auth uses Keystone v3 with separate `user_domain_name` and `project_domain_name`
- Root compute receives network/volume name-to-ID maps. Image and flavor names resolve through data sources; dynamic block devices support booting from a Cinder volume.

### Vultr
- `VULTR_API_KEY` env var only — setting `api_key` in tfvars to ANYTHING (including a placeholder) overrides the env-var fallback. The variable must stay `null`
- `vultr_vpc` v1 is used (`vultr_vpc2` is deprecated upstream — do not "upgrade")
- Root passes VPC/firewall-group ID maps to compute; the compute module resolves instance references including SSH-key/startup-script names using its own resources.
- Local backend — back up state via `tfvars-sync.sh --file terraform.tfstate`

## What this repo does NOT have

- No CI/CD configs (no `.github/`, no Makefile, no Taskfile)
- No pre-commit hooks
- No `.terraform-version` or `.tool-versions`
- No Docker, no docker-compose
- No tests (`*.tftest.hcl`)

## When adding a new Terraform module

1. Replicate the existing structure: `main.tf` + `variables.tf` + `outputs.tf` + `versions.tf`
2. Use `optional(type, default)` in variable type definitions
3. Use `flatten()` + `for_each` with compound keys for nested inputs
4. Use dynamic blocks for optional resource attributes
5. Add platform input `validation` blocks in `<platform>/variables.tf`; reusable modules may additionally validate their own contracts
6. Wire through the root module (`<platform>/main.tf`) with `for` expressions if name→ID resolution is needed; update env forwarding, shared interfaces, outputs, templates, and documentation together

## See also

- `README.md` — repository quick start
- `gcp/README.md`, `aws/README.md`, `proxmox/README.md`, `openstack/README.md` — platform guides (Vultr currently uses the root README)
