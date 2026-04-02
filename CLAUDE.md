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

AWS Terraform operations run from environment directories (`aws/envs/devtest/`):

```bash
# Initialize (with S3 backend)
cd aws/envs/devtest
terraform init -backend-config=backend.hcl

# Or initialize with local state (no backend)
terraform init -backend=false

# Plan and apply
terraform plan
terraform apply

# Validate configuration
terraform validate

# Format check
terraform fmt -check -recursive
```

## Architecture

### GCP (primary, production-ready)

Three-layer module architecture:

1. **Root module** (`gcp/main.tf`) — Wires 6 submodules together (network, nat, iam, storage, compute, lb). Contains a `locals` block that resolves instance group name references to self_links for the LB module.

2. **Reusable modules** (`gcp/modules/{compute,iam,lb,nat,network,storage}/`) — Each module follows the standard `main.tf` + `variables.tf` + `outputs.tf` + `versions.tf` pattern. Resources are created with `for_each` over object maps derived from flat input lists.

3. **Environment configs** (`gcp/envs/{devtest,prod}/`) — Each env has its own `main.tf` (provider + backend + root module call) and `backend.hcl` (GCS bucket/prefix). `variables.tf` and `outputs.tf` are **symlinks** to `gcp/_shared/` — do not edit them in env dirs.

#### GCP module details

| Module | Resources | Key features |
|--------|-----------|--------------|
| **network** | `google_compute_network`, `google_compute_subnetwork`, `google_compute_firewall` | Auto-create subnets disabled, MTU 1460, private IP Google Access, `firewall_attrs` local converts empty lists to null |
| **nat** | `google_compute_router`, `google_compute_address`, `google_compute_router_nat` | Dynamic Port Allocation (DPA) support, external IPs only for MANUAL_ONLY mode, dynamic `log_config` block |
| **iam** | `google_service_account`, `google_project_iam_member`, `google_service_account_iam_member` | Non-authoritative `*_iam_member`, Workload Identity for KSA impersonation, `flat_bindings` local flattens roles per SA |
| **storage** | `google_storage_bucket`, `google_storage_bucket_iam_member` | Uniform bucket-level access, public_access_prevention enforced by default, dynamic `lifecycle_rule` blocks with `matches_prefix` support, triple-nested flatten for bucket IAM |
| **compute** | `google_compute_address`, `google_compute_instance`, `google_compute_disk`, `google_compute_attached_disk`, `google_compute_instance_group` | Shielded instance (secure_boot, vTPM, integrity_monitoring), cloud-init via `templatefile()`, dynamic `access_config` for external IP, new vs existing disk separation |
| **lb** | `google_compute_global_address`, `google_compute_health_check`, `google_compute_backend_service`, `google_compute_url_map`, `google_compute_target_http_proxy`, `google_compute_global_forwarding_rule`, `google_compute_managed_ssl_certificate`, `google_compute_target_https_proxy` | EXTERNAL_MANAGED scheme (new ALB), shared IP via `global_address_name`, conditional SSL/HTTPS resources, UTILIZATION or RATE balancing modes |

### AWS (modular, network module complete)

Same three-layer architecture as GCP:

1. **Root module** (`aws/main.tf`) — Calls the network module, with placeholders for future modules (compute, iam, storage, lb).

2. **Reusable modules** (`aws/modules/network/`) — VPC, subnets, IGW, NAT GW + EIP, route tables, security groups, and SG rules. Uses `flatten()` + `for_each` with compound keys (`"vpc-name/subnet-name"`).

3. **Environment configs** (`aws/envs/devtest/`) — Provider + S3 backend + root module call. `variables.tf` and `outputs.tf` are **symlinks** to `aws/_shared/` — do not edit them in env dirs.

**Routing design**: One public route table per VPC (0.0.0.0/0 → IGW), one private route table per NAT gateway (0.0.0.0/0 → NAT GW), isolated subnets use VPC default route table.

#### AWS network module resources

`aws_vpc` (DNS support + hostnames), `aws_subnet`, `aws_internet_gateway` (conditional on public subnets), `aws_eip` + `aws_nat_gateway`, `aws_route_table` + `aws_route` + `aws_route_table_association` (public/private/isolated), `aws_security_group` + `aws_vpc_security_group_ingress_rule` / `aws_vpc_security_group_egress_rule`.

### Key patterns (shared by GCP and AWS)

- **Flattening nested inputs**: Modules use `locals` with `flatten()` to convert nested lists (e.g., networks with subnets) into flat maps keyed by compound keys like `"vpc-name/subnet-name"` for use with `for_each`.
- **Optional attributes with defaults**: Variables use `optional(type, default)` extensively (e.g., `disk_size = optional(number, 20)`).
- **Dynamic blocks**: Used for conditional resource attributes (e.g., `access_config` only when `external_ip = true`).
- **Cross-module references**: LB module receives instance group self_links resolved in root module's `locals` block; resources reference networks/subnets by name strings mapped at the module level.
- **Cloud-init templating**: `gcp/templates/cloud-init.yaml.tpl` is rendered via `templatefile()` in the compute module for VM initialization (Docker, packages, hostname).
- **Non-authoritative IAM**: Uses `*_iam_member` (not `*_iam_binding`) to avoid overwriting external bindings.
- **Comprehensive validation**: Heavy use of `validation` blocks with regex, `contains()`, `alltrue()`, and nested `flatten()` for deep input validation.
- **Conditional resource creation**: Resources created only when needed (e.g., external IPs only when `external_ip = true`, SSL resources only when `ssl_config.enabled`, IGW only if VPC has public subnets).

### State management

- **GCP**: GCS backend per environment, configured via `backend.hcl` files. Same GCS bucket stores both state files and team-shared tfvars (via `tfvars-sync.sh`). State prefix pattern: `gcp/{env_name}` (e.g., `gcp/devtest`, `gcp/prod`).
- **AWS**: S3 backend per environment, configured via `backend.hcl` files. State key pattern: `aws/{env_name}/terraform.tfstate`.

### What's gitignored

`*.tfvars`, `*.tfstate`, `*.json` (except tfvars.json), `**/keys/`, `.terraform/`. Use `gcp/envs/terraform.tfvars.example` and `aws/envs/terraform.tfvars.example` as the reference templates for tfvars.

## Provider versions

- Terraform `~> 1.5`
- `hashicorp/google` and `hashicorp/google-beta` `~> 7.0`
- `hashicorp/aws` `~> 5.0`
