# AGENTS.md

## Verification commands

All Terraform commands run from **env directories** (`<platform>/envs/<env>/`), never the repo root. There is no test framework — verification is:

```bash
terraform fmt -check -recursive   # from repo root works
terraform validate                 # must run from an env dir (after terraform init)
```

## Architecture gotchas

- **Four independent platforms** (`gcp/`, `aws/`, `proxmox/`, `openstack/`), each with the same three-layer pattern: root module → `modules/` → `envs/<env>/`.
- **Symlinked files**: `variables.tf` and `outputs.tf` in every env dir are symlinks to `<platform>/_shared/`. Edit the `_shared/` originals, never the symlinks.
- **Not symlinked**: Each env's `main.tf` is an independent copy (providers, backend block, module call). `gcp/_shared/main.tf` is a reference template only — it is **not** kept in sync with env `main.tf` files and may lag behind.
- **`gcp/_shared/` also has `providers.tf`** that is not used by envs (envs declare providers inline in their own `main.tf`).

## Module patterns

- Modules use `flatten()` + `for_each` over compound-keyed maps (e.g., `"vpc-name/subnet-name"`). When adding new resource types, follow this pattern — do not use `count`.
- Variables use `optional(type, default)` extensively. New variables should follow this convention.
- IAM uses `*_iam_member` resources (non-authoritative) — never `*_iam_binding` or `*_policy`.
- Conditional resources use `dynamic` blocks or `for_each` with filtered maps, not `count`.
- Cloud-init templates use `templatefile()` (see `gcp/templates/cloud-init.yaml.tpl`).

## Platform-specific notes

### GCP
- GKE module requires the `google-beta` provider (both providers are declared in env `main.tf`).
- The root module `gcp/main.tf` has a `locals` block that resolves instance group names to self_links for the LB module — changes to instance group naming may require updating this block.
- `tfvars-sync.sh` syncs tfvars to/from the same GCS bucket used for state.

### Proxmox
- Provider `bpg/proxmox` is pinned to `~> 0.104.0`. v0.105+ has a schema bug on the `ports` attribute that breaks `terraform validate`. Do not bump without verifying upstream fix.

### OpenStack
- `terraform init` requires Swift EC2 credentials exported as `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` before running (the S3 backend targets Swift's S3-compatible API).

## tfvars

- `*.tfvars` and `*.tfvars.json` are gitignored. Example templates live at `<platform>/envs/terraform.tfvars.example`.
- To create a new env, copy an existing env dir, update `backend.hcl`, and create `terraform.tfvars` from the example template.

## Style

- No comments in `.tf` files unless asked.
- Follow existing `main.tf` + `variables.tf` + `outputs.tf` + `versions.tf` structure per module.
