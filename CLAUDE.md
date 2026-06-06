# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Common Commands

All GCP Terraform operations run from environment directories (`gcp/envs/dev/` or `gcp/envs/prod/`):

```bash
# Initialize (required once per environment)
cd gcp/envs/dev
terraform init -backend-config=backend.hcl

# Plan and apply
terraform plan
terraform apply

# Validate configuration
terraform validate

# Format check
terraform fmt -check -recursive

# Sync tfvars with team — GCS / S3 / R2 (script auto-derives the remote URI from backend.hcl)
./scripts/tfvars-sync.sh download --platform gcp --storage gcs              # all gcp envs
./scripts/tfvars-sync.sh download --platform gcp --storage gcs --env dev    # one gcp env
./scripts/tfvars-sync.sh upload   --platform gcp --storage gcs --env prod
./scripts/tfvars-sync.sh upload   --platform aws --storage r2  --env logic3579
./scripts/tfvars-sync.sh upload   --platform aws --storage s3  --env dev --dry-run
```

AWS Terraform operations run from environment directories (`aws/envs/dev/`):

```bash
# Initialize (with S3 backend)
cd aws/envs/dev
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

Proxmox VE Terraform operations run from environment directories (`proxmox/envs/dev/`):

```bash
# Initialize (local backend — no -backend-config needed)
cd proxmox/envs/dev
terraform init

# Plan and apply
terraform plan
terraform apply
```

OpenStack Terraform operations run from environment directories (`openstack/envs/dev/`):

```bash
# State backend uses Swift's S3-compatible API; export EC2 creds first
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...

cd openstack/envs/dev
terraform init -backend-config=backend.hcl

# Plan and apply
terraform plan
terraform apply
```

## Architecture

### GCP (primary, production-ready)

Three-layer module architecture:

1. **Root module** (`gcp/main.tf`) — Wires 8 submodules together (network, nat, iam, storage, compute, lb, neg-lb, gke). Contains a `locals` block that resolves instance group name references to self_links for the LB module.

2. **Reusable modules** (`gcp/modules/{compute,gke,iam,lb,nat,neg-lb,network,storage}/`) — Each module follows the standard `main.tf` + `variables.tf` + `outputs.tf` + `versions.tf` pattern. Resources are created with `for_each` over object maps derived from flat input lists.

3. **Environment configs** (`gcp/envs/{dev,prod}/`) — Each env has its own `main.tf` (provider + backend + root module call) and `backend.hcl` (GCS bucket/prefix). `variables.tf` and `outputs.tf` are **symlinks** to `gcp/_shared/` — do not edit them in env dirs. `envs/dev/` is the included example; replicate it to `envs/test/`, `envs/uat/`, etc. as needed.

#### GCP module details

| Module | Resources | Key features |
|--------|-----------|--------------|
| **network** | `google_compute_network`, `google_compute_subnetwork`, `google_compute_firewall` | Auto-create subnets disabled, MTU 1460, private IP Google Access, `firewall_attrs` local converts empty lists to null |
| **nat** | `google_compute_router`, `google_compute_address`, `google_compute_router_nat` | Dynamic Port Allocation (DPA) support, external IPs only for MANUAL_ONLY mode, dynamic `log_config` block |
| **iam** | `google_service_account`, `google_project_iam_member`, `google_service_account_iam_member` | Non-authoritative `*_iam_member`, Workload Identity for KSA impersonation, `flat_bindings` local flattens roles per SA |
| **storage** | `google_storage_bucket`, `google_storage_bucket_iam_member` | Uniform bucket-level access, public_access_prevention enforced by default, dynamic `lifecycle_rule` blocks with `matches_prefix` support, triple-nested flatten for bucket IAM |
| **compute** | `google_compute_address`, `google_compute_instance`, `google_compute_disk`, `google_compute_attached_disk`, `google_compute_instance_group` | Shielded instance (secure_boot, vTPM, integrity_monitoring), cloud-init via `templatefile()`, dynamic `access_config` for external IP, new vs existing disk separation |
| **lb** | `google_compute_global_address`, `google_compute_health_check`, `google_compute_backend_service`, `google_compute_url_map`, `google_compute_target_http_proxy`, `google_compute_global_forwarding_rule`, `google_compute_managed_ssl_certificate`, `google_compute_target_https_proxy` | EXTERNAL_MANAGED scheme (new ALB), shared IP via `global_address_name`, conditional SSL/HTTPS resources, UTILIZATION or RATE balancing modes |
| **neg-lb** | `data.google_compute_network_endpoint_group`, `google_compute_global_address`, `google_compute_health_check`, `google_compute_backend_service`, `google_compute_url_map`, `google_compute_target_http_proxy`, `google_compute_global_forwarding_rule`, `google_compute_managed_ssl_certificate`, `google_compute_target_https_proxy` | NEG-backed ALB for GKE Standalone NEGs, data source lookup of existing NEGs by name+zone, HTTP/TCP health checks, RATE or UTILIZATION balancing per endpoint, conditional SSL/HTTPS |
| **gke** | `google_container_cluster`, `google_container_node_pool` | Autopilot and Standard modes, VPC-native networking, private cluster, master authorized networks, Dataplane V2, Cloud DNS, Gateway API, maintenance window, release channel, logging/monitoring with Managed Prometheus, addons (HTTP LB, HPA, PD CSI, GCS Fuse CSI, DNS cache, Config Connector, GKE Backup, Stateful HA), Workload Identity, security posture, node pool autoscaling/spot/GPU/taints, uses `google-beta` provider |

### AWS (modular, 6 modules)

Same three-layer architecture as GCP:

1. **Root module** (`aws/main.tf`) — Wires 6 submodules together (network, iam, compute, rds, lambda, budget). Threads `module.network` subnet/SG ID maps into `compute` / `rds`, and `module.iam` instance-profile / role ARN maps into `compute` / `lambda`.

2. **Reusable modules** (`aws/modules/{network,iam,compute,rds,lambda,budget}/`) — Each follows the standard `main.tf` + `variables.tf` + `outputs.tf` + `versions.tf` pattern. Resources are created with `for_each` over object maps; nested inputs flatten via `locals` with compound keys.

3. **Environment configs** (`aws/envs/{dev,logic3579}/`) — Provider + S3 backend + root module call. `variables.tf` and `outputs.tf` are **symlinks** to `aws/_shared/` — do not edit them in env dirs.
   - `envs/dev/` uses an S3 backend (placeholder bucket).
   - `envs/logic3579/` uses an **S3 backend pointed at Cloudflare R2** via `endpoints.s3` + skip flags; its `backend.hcl` embeds R2 credentials directly (gitignored — see `.gitignore`). The reusable template lives at `aws/envs/backend.hcl.example`.
   - The AWS provider's `region` and `profile` are sourced from `var.region` / `var.aws_profile`. For SSO users on AWS CLI ≥ 2.27 (new `aws login` command writing to `~/.aws/login/`), the Go SDK can't read that cache directly — bridge it via a `[profile terraform]` in `~/.aws/config` with `credential_process = aws configure export-credentials --profile default --format process`, then set `aws_profile = "terraform"` in tfvars.

**Routing design**: One public route table per VPC (0.0.0.0/0 → IGW), one private route table per NAT gateway (0.0.0.0/0 → NAT GW), isolated subnets use VPC default route table.

#### AWS module details

| Module | Resources | Key features |
|--------|-----------|--------------|
| **network** | `aws_vpc`, `aws_subnet`, `aws_internet_gateway`, `aws_eip` + `aws_nat_gateway`, `aws_route_table` + `aws_route` + `aws_route_table_association`, `aws_security_group` + `aws_vpc_security_group_ingress_rule` / `_egress_rule` | Public / private (with NAT) / isolated subnet routing. SG rules auto-null `from_port`/`to_port` when `protocol = "-1"` (AWS rejects the combination). **Limitation**: SG ingress/egress rule resources only honor `cidr_blocks[0]` — split per CIDR for full coverage. |
| **iam** | `aws_iam_role`, `aws_iam_instance_profile`, `aws_iam_role_policy_attachment` | One role + one instance profile per `ec2_instance_profiles` entry (same name). Lambda execution roles created separately. Outputs `ec2_instance_profile_names` and `lambda_role_arns` maps for root wiring. |
| **compute** | `aws_key_pair`, `aws_instance`, `aws_eip`, `data.aws_ami` | AMI lookup presets (`debian-12`, `al2023`, `ubuntu-22`) — set `os` or `ami_id`. IMDSv2 required by default. Optional Elastic IP per instance. `iam_instance_profile` resolves via the iam-module-supplied map. `user_data` ignored on in-place changes. |
| **rds** | `random_password`, `aws_ssm_parameter` (SecureString), `aws_db_subnet_group`, `aws_db_instance` | Master password is randomly generated and written to SSM Parameter Store at `ssm_password_path` (default `/<name>/master_password`). DB subnet group requires `subnet_names` in ≥2 AZs. `engine_version` is ignored on changes so AWS-side minor upgrades don't trigger replacement. |
| **lambda** | `data.archive_file`, `aws_lambda_function`, `aws_lambda_function_url` | Source is zipped from `${path.root}/<source_dir>` (relative to env dir). Function URL optional, auth `NONE` or `AWS_IAM`. Role resolved via the iam-module-supplied map. Uses the `hashicorp/archive` provider. |
| **budget** | `aws_budgets_budget` | Supports `time_unit` DAILY / MONTHLY / QUARTERLY / ANNUALLY and multiple email notifications per budget (PERCENTAGE or ABSOLUTE_VALUE thresholds). |

### Proxmox VE (basic, extensible)

Same three-layer architecture as GCP/AWS:

1. **Root module** (`proxmox/main.tf`) — Calls 3 submodules (network, storage, compute). Provider/backend live in `envs/<env>/main.tf`.

2. **Reusable modules** (`proxmox/modules/{network,storage,compute}/`) — Standard `main.tf` + `variables.tf` + `outputs.tf` + `versions.tf` pattern. Resources use `for_each` over object maps; compute uses `dynamic` blocks for `disk`, `network_device`, and `initialization` (cloud-init).

3. **Environment configs** (`proxmox/envs/dev/`) — Provider + local backend + root module call. `variables.tf` and `outputs.tf` are **symlinks** to `proxmox/_shared/`. Copy `envs/dev/` to `envs/test/`, `envs/prod/`, etc. when adding environments.

#### Proxmox module details

| Module | Resources | Key features |
|--------|-----------|--------------|
| **network** | `proxmox_virtual_environment_network_linux_bridge` | Linux bridges (vmbrN) on PVE nodes, optional CIDR/gateway/VLAN-aware/MTU |
| **storage** | `proxmox_virtual_environment_download_file` | Downloads ISOs / cloud images / LXC templates (vztmpl) into a PVE datastore; output `id` usable as `file_id` on a VM disk |
| **compute** | `proxmox_virtual_environment_vm` | KVM VMs with `cpu`/`memory`/`agent` blocks, dynamic `disk` and `network_device` lists, optional cloud-init `initialization` (user_account / ip_config / dns dynamic sub-blocks) |

**Provider auth**: API token preferred (`user@realm!tokenid=secret`), with username/password fallback. Optional `ssh` block for snippet uploads.

**Provider version pin**: `bpg/proxmox` is pinned to `~> 0.104.0`. v0.105 introduced a Plugin Framework rewrite of the network resources that has a schema bug on the `ports` attribute, breaking `terraform validate`. Bump the pin (and rename to `proxmox_network_linux_bridge`) once upstream fixes it.

### OpenStack (basic, extensible)

Same three-layer architecture as GCP/AWS:

1. **Root module** (`openstack/main.tf`) — Calls 3 submodules (network, storage, compute). The compute module receives `network_id_by_name` and `volume_id_by_name` maps from the network/storage modules so instances can reference them by name.

2. **Reusable modules** (`openstack/modules/{network,storage,compute}/`) — Standard pattern. Network module flattens nested subnets, router interfaces, and SG rules with `flatten()` + compound keys.

3. **Environment configs** (`openstack/envs/dev/`) — Provider + S3 backend (pointed at Swift's S3-compatible API) + root module call. `variables.tf` / `outputs.tf` are **symlinks** to `openstack/_shared/`. Copy `envs/dev/` to `envs/test/`, `envs/prod/`, etc. when adding environments.

#### OpenStack module details

| Module | Resources | Key features |
|--------|-----------|--------------|
| **network** | `openstack_networking_network_v2`, `_subnet_v2`, `_router_v2`, `_router_interface_v2`, `_secgroup_v2`, `_secgroup_rule_v2`, `_floatingip_v2` (+ `data.openstack_networking_network_v2` for external-network lookups) | Flatten subnets/interfaces/rules into compound-keyed maps; SG rules can reference another SG by name (`remote_group`) |
| **compute** | `openstack_compute_instance_v2`, `_keypair_v2` (+ `data.openstack_images_image_v2` and `data.openstack_compute_flavor_v2`) | Image/flavor resolved by name via data sources; dynamic `network` blocks; optional `block_device` boot from a Cinder volume created by the storage module |
| **storage** | `openstack_blockstorage_volume_v3` (+ `data.openstack_images_image_v2` for source images) | Cinder volumes with optional source image |

**Provider auth**: Keystone v3 (separate `user_domain_name` / `project_domain_name`).

### Key patterns (shared by GCP, AWS, Proxmox, OpenStack)

- **Flattening nested inputs**: Modules use `locals` with `flatten()` to convert nested lists (e.g., networks with subnets) into flat maps keyed by compound keys like `"vpc-name/subnet-name"` for use with `for_each`.
- **Optional attributes with defaults**: Variables use `optional(type, default)` extensively (e.g., `disk_size = optional(number, 20)`).
- **Dynamic blocks**: Used for conditional resource attributes (e.g., `access_config` only when `external_ip = true`).
- **Cross-module references**: LB module receives instance group self_links resolved in root module's `locals` block; resources reference networks/subnets by name strings mapped at the module level.
- **Cloud-init templating**: `gcp/templates/cloud-init.yaml.tpl` is rendered via `templatefile()` in the compute module for VM initialization (Docker, packages, hostname).
- **Non-authoritative IAM**: Uses `*_iam_member` (not `*_iam_binding`) to avoid overwriting external bindings.
- **Comprehensive validation**: Heavy use of `validation` blocks with regex, `contains()`, `alltrue()`, and nested `flatten()` for deep input validation.
- **Conditional resource creation**: Resources created only when needed (e.g., external IPs only when `external_ip = true`, SSL resources only when `ssl_config.enabled`, IGW only if VPC has public subnets).

### State management

- **GCP**: GCS backend per environment, configured via `backend.hcl` files. Same GCS bucket stores both state files and team-shared tfvars (via `tfvars-sync.sh`). State prefix pattern: `gcp/{env_name}` (e.g., `gcp/dev`, `gcp/prod`).
- **AWS**: S3 backend per environment, configured via `backend.hcl` files. State key pattern: `aws/{env_name}/terraform.tfstate`. Backend can point at any S3-compatible store via `endpoints.s3` — `envs/logic3579/` uses **Cloudflare R2** (skip flags + `use_path_style = true`; R2 credentials embedded in the gitignored `backend.hcl` to avoid colliding with the AWS provider's `AWS_ACCESS_KEY_ID`/`_SECRET_ACCESS_KEY` env vars). No DynamoDB locking on R2; Terraform 1.10+ native S3 lockfile (`use_lockfile = true`) is the alternative.
- **Proxmox**: Local backend (`terraform.tfstate` in the env dir). Proxmox has no native Terraform backend — common alternatives for team use are an S3-compatible store like MinIO or the HTTP backend backed by GitLab/Gitea.
- **OpenStack**: S3 backend pointed at Swift's S3-compatible API (the native `swift` backend was removed in Terraform 1.3). Generate Swift EC2 credentials with `openstack ec2 credentials create`, export them as `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`, then `terraform init -backend-config=backend.hcl`. State key pattern: `openstack/{env_name}/terraform.tfstate`.

### What's gitignored

`*.tfvars`, `*.tfstate`, `*.json` (except tfvars.json), `**/keys/`, `.terraform/`. Per-env `backend.hcl` files that embed credentials are gitignored on a path-by-path basis (e.g., `aws/envs/logic3579/backend.hcl`). Use `gcp/envs/terraform.tfvars.example`, `aws/envs/terraform.tfvars.example`, `aws/envs/backend.hcl.example`, `proxmox/envs/terraform.tfvars.example`, and `openstack/envs/terraform.tfvars.example` as the reference templates.

## Provider versions

- Terraform `~> 1.5`
- `hashicorp/google` and `hashicorp/google-beta` `~> 7.0`
- `hashicorp/aws` `~> 5.0`
- `bpg/proxmox` `~> 0.104.0` (see Proxmox section for the pin reason)
- `terraform-provider-openstack/openstack` `~> 3.4`
