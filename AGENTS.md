# AGENTS.md

Compact instruction file for OpenCode sessions working in this Terraform monorepo. Every line answers: "Would an agent likely miss this without help?"

## Repository layout

Five platforms sharing the same three-layer architecture:

```
<platform>/modules/<name>/       # Reusable submodule: main.tf + variables.tf + outputs.tf + versions.tf
<platform>/_shared/              # variables.tf, outputs.tf (symlinked into each env)
<platform>/envs/<env>/           # One dir per env: provider + backend + root module call
<platform>/main.tf               # Root module — wires submodules
```

**GCP** (8 modules), **AWS** (6), **Proxmox** (3), **OpenStack** (3), **Vultr** (2).

## Critical: symlinks — do NOT edit in env dirs

Every `envs/<env>/variables.tf` and `envs/<env>/outputs.tf` is a **symlink** to `../../_shared/`. The only files you edit in an env dir are:
- `main.tf` (provider/backend/module call — NOT symlinked)
- `terraform.tfvars` (gitignored)
- `backend.hcl` (gitignored)

If you write to a symlinked file, you corrupt the symlink and break every environment using it.

## .gitignore — what's never committed

`*.tfvars`, `*.tfstate`, `*.tfstate.*`, `**/keys/`, `.terraform/`, and **`**/backend.hcl`** (credentials). Reference templates live as `.example` files next to each platform's `envs/`.

## Per-platform operational commands

All Terraform commands run from the env directory. Each platform has auth/backend quirks:

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

## Adding a new environment

```bash
cp -r <platform>/envs/dev <platform>/envs/<new-env>
cd <platform>/envs/<new-env>
# symlinks for variables.tf and outputs.tf already work (relative paths)
cp ../backend.hcl.example backend.hcl   # fill in
cp ../terraform.tfvars.example terraform.tfvars   # fill in
```

## State management & tfvars-sync.sh

`scripts/tfvars-sync.sh upload|download --platform X --storage s3|r2|gcs [--env Y]` syncs `terraform.tfvars` (and optionally `terraform.tfstate`) to remote object storage. Defaults: `--file terraform.tfvars`, `--bucket terraform-state`. For `--storage r2`, `--endpoint` is required and `S3_ACCESS_KEY`/`S3_SECRET_ACCESS_KEY` env vars are mandatory.

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

Always use `*_iam_member` (not `*_iam_binding`). Never use authoritative bindings — they destroy external role assignments.

### Validation blocks on root variables

Root-level `variables.tf` (in `<platform>/variables.tf`, NOT `_shared/`) uses `validation` blocks with `can(regex(...))` and `contains([...])`. Check these before adding new variables.

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
- `envs/logic3579/` uses `aws_profile = "logic3579-admin"` (IAM Identity Center SSO), and points the S3 backend at Cloudflare R2 via `endpoints.s3` — no DynamoDB locking; uses TF 1.10+ native S3 lockfile

### Proxmox
- Provider pinned `~> 0.104.0` — DO NOT BUMP. Network resource name is `proxmox_virtual_environment_network_linux_bridge` (will change when bumped)
- No native backend — state is local. Back up `terraform.tfstate` via `tfvars-sync.sh --file terraform.tfstate`

### OpenStack
- State backend is S3 pointed at Swift's S3-compatible API — set `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY` to Swift EC2 credentials
- Auth uses Keystone v3 with separate `user_domain_name` and `project_domain_name`

### Vultr
- `VULTR_API_KEY` env var only — setting `api_key` in tfvars to ANYTHING (including a placeholder) overrides the env-var fallback. The variable must stay `null`
- `vultr_vpc` v1 is used (`vultr_vpc2` is deprecated upstream — do not "upgrade")
- Name-based cross-references in the root module: SSH keys, startup scripts, firewall groups, VPCs are resolved by name → ID before being passed to the compute module
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
5. Add `validation` blocks at the root level (`<platform>/variables.tf`), not in the module
6. Wire through the root module (`<platform>/main.tf`) with `for` expressions if name→ID resolution is needed

## See also

- `CLAUDE.md` — full architecture details, module-by-module resource tables, and extended command reference
- `<platform>/README.md` — per-platform quick-start guides
