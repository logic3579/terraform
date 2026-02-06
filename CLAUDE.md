# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Common Commands

All GCP Terraform operations run from environment directories (`gcp/envs/devtest/` or `gcp/envs/prod/`):

```bash
# Initialize (required once per environment)
cd gcp/envs/devtest
terraform init -backend-config=backend.hcl

# Plan and apply
terraform plan
terraform apply

# Validate configuration
terraform validate

# Format check
terraform fmt -check -recursive

# Sync tfvars with team via GCS
./gcp/scripts/tfvars-sync.sh download          # all envs
./gcp/scripts/tfvars-sync.sh download devtest   # specific env
./gcp/scripts/tfvars-sync.sh upload prod        # upload specific env
```

AWS is a flat structure under `aws/` — run `terraform init/plan/apply` directly from there (local state, no backend).

## Architecture

### GCP (primary, production-ready)

Three-layer module architecture:

1. **Root module** (`gcp/main.tf`) — Wires 6 submodules together (network, nat, iam, storage, compute, lb). Contains a `locals` block that resolves instance group name references to self_links for the LB module.

2. **Reusable modules** (`gcp/modules/{compute,iam,lb,nat,network,storage}/`) — Each module follows the standard `main.tf` + `variables.tf` + `outputs.tf` + `versions.tf` pattern. Resources are created with `for_each` over object maps derived from flat input lists.

3. **Environment configs** (`gcp/envs/{devtest,prod}/`) — Each env has its own `main.tf` (provider + backend + root module call) and `backend.hcl` (GCS bucket/prefix). `variables.tf` and `outputs.tf` are **symlinks** to `gcp/_shared/` — do not edit them in env dirs.

### Key patterns

- **Flattening nested inputs**: Modules use `locals` with `flatten()` to convert nested lists (e.g., networks with subnets) into flat maps keyed by compound keys like `"vpc-name/subnet-name"` for use with `for_each`.
- **Optional attributes with defaults**: Variables use `optional(type, default)` extensively (e.g., `disk_size = optional(number, 20)`).
- **Dynamic blocks**: Used for conditional resource attributes (e.g., `access_config` only when `external_ip = true`).
- **Cross-module references**: LB module receives instance group self_links resolved in root module's `locals` block; resources reference networks/subnets by name strings mapped at the module level.
- **Cloud-init templating**: `gcp/templates/cloud-init.yaml.tpl` is rendered via `templatefile()` in the compute module for VM initialization (Docker, packages, hostname).

### State management

- GCS backend per environment, configured via `backend.hcl` files
- Same GCS bucket stores both state files and team-shared tfvars (via `tfvars-sync.sh`)
- State prefix pattern: `gcp/{env_name}` (e.g., `gcp/devtest`, `gcp/prod`)

### What's gitignored

`*.tfvars`, `*.tfstate`, `*.json` (except tfvars.json), `**/keys/`, `.terraform/`. Use `gcp/envs/terraform.tfvars.example` as the reference template for tfvars.

## Provider versions

- Terraform `~> 1.5`
- `hashicorp/google` and `hashicorp/google-beta` `~> 7.0`
- AWS provider `~> 4.0` (aws/ directory only)
