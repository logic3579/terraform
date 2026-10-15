# Terraform Infrastructure as Code

Terraform configurations for provisioning infrastructure on **GCP**, **AWS**, **Proxmox VE**, **OpenStack**, and **Vultr**.

## Structure

```
.
├── gcp/         # Google Cloud Platform — production-ready (8 modules)
├── aws/         # Amazon Web Services — 6 modules (network, iam, compute, rds, lambda, budget)
├── proxmox/     # Proxmox VE — basic VM/network/storage (bpg/proxmox)
├── openstack/   # OpenStack — basic compute/network/storage (terraform-provider-openstack)
├── vultr/       # Vultr — VPC + firewall groups + compute instances (vultr/vultr)
└── scripts/     # terraform.tfvars upload/download for S3, R2, and GCS
```

Each platform follows the same three-layer architecture:

- **Root module** wires reusable submodules together.
- **`modules/`** — reusable submodules; one resource family per submodule (`main.tf` + `variables.tf` + `outputs.tf` + `versions.tf`).
- **`envs/<env>/`** — provider, backend, and module-call wiring per environment. `variables.tf` and `outputs.tf` in env dirs are **symlinks** to `<platform>/_shared/`.

## Prerequisites

1. Install Terraform `~> 1.5` — [installation guide](https://learn.hashicorp.com/tutorials/terraform/install-cli).
2. Authenticate against the cloud you'll target:
   - **GCP**: [provider auth](https://registry.terraform.io/providers/hashicorp/google/latest/docs/guides/getting_started)
   - **AWS**: [provider auth](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/)
   - **Proxmox**: API token (`Datacenter → Permissions → API Tokens`) or username/password
   - **OpenStack**: Keystone v3 credentials; for state backend, also Swift EC2 creds (`openstack ec2 credentials create`)
   - **Vultr**: API key — generate at https://my.vultr.com/settings/#settingsapi, then `export VULTR_API_KEY=...`

## Usage

Run Terraform commands from the target env directory. The tracked environments
and state backends are:

| Platform | Environments | Backend | State prefix or key |
|----------|--------------|---------|---------------------|
| GCP | `dev`, `base` | GCS | `gcp/<env>` prefix |
| GCP | `logic3579` | S3-compatible R2 | `gcp/logic3579/terraform.tfstate` |
| AWS | `dev`, `logic3579` | S3-compatible | `aws/<env>/terraform.tfstate` |
| Proxmox | `dev` | Local | `terraform.tfstate` in the env directory |
| OpenStack | `dev` | S3-compatible Swift | `openstack/<env>/terraform.tfstate` |
| Vultr | `logic3579` | S3-compatible R2 | `vultr/logic3579/terraform.tfstate` |

For remote backends, copy `<platform>/envs/backend.hcl.example` to the env
directory as `backend.hcl` and fill in the bucket, unique state path, and
authentication settings. The GCP template has separate GCS and R2 examples;
choose the section matching the backend type in the env's `main.tf`.
`backend.hcl` is **not loaded automatically**: pass
`terraform init -backend-config=backend.hcl` explicitly.

`backend.hcl` and `terraform.tfvars` are gitignored and must be supplied on each
checkout. GCP, AWS, and Vultr `logic3579` can share the R2 bucket and endpoint
while keeping the distinct state keys above. Backend credentials are separate
from each cloud provider's credentials.

When moving an existing local state to a remote backend, use
`terraform init -migrate-state -backend-config=backend.hcl`. When there is no
state to migrate, use `terraform init -reconfigure -backend-config=backend.hcl`
to replace a previously initialized backend configuration.

### GCP

```bash
cd gcp/envs/dev
cp ../terraform.tfvars.example terraform.tfvars   # then edit
cp ../backend.hcl.example backend.hcl             # then edit; select GCS
terraform init -backend-config=backend.hcl
terraform plan
terraform apply
```

`gcp/envs/logic3579/` uses the same root module with an S3 backend. Set
`project_id = "logic3579"` in its local tfvars. The `env` value is independent
of the directory name and accepts `base`, `dev`, `test`, `uat`, or `prod`.
The initial location values follow `base`: `asia-east2` / `asia-east2-a`.
Resource lists default to empty; add only the resources you intend to manage.

### AWS

```bash
cd aws/envs/dev
cp ../terraform.tfvars.example terraform.tfvars   # then edit
cp ../backend.hcl.example backend.hcl             # R2 example; adapt for AWS S3
terraform init -backend-config=backend.hcl
terraform plan
terraform apply
```

### Proxmox VE

```bash
cd proxmox/envs/dev
cp ../terraform.tfvars.example terraform.tfvars   # then edit
terraform init                                    # local backend
terraform plan
terraform apply
```

### OpenStack

```bash
cd openstack/envs/dev
cp ../terraform.tfvars.example terraform.tfvars   # then edit
cp ../backend.hcl.example backend.hcl             # then edit

# State backend uses Swift's S3-compatible API
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...

terraform init -backend-config=backend.hcl
terraform plan
terraform apply
```

### Vultr

```bash
export VULTR_API_KEY=...                          # provider reads this env var natively
cd vultr/envs/logic3579
cp ../terraform.tfvars.example terraform.tfvars   # then edit
cp ../backend.hcl.example backend.hcl             # then fill in backend values
terraform init -backend-config=backend.hcl
terraform plan
terraform apply
```

Leave `api_key` unset in tfvars so the provider reads `VULTR_API_KEY`.
Export it in the same shell that runs `terraform plan` or `apply`.

## Sync terraform.tfvars

Run `scripts/tfvars-sync.sh` from the repository root to upload or download only
`terraform.tfvars`. Objects use `<platform>/<env>/terraform.tfvars`; the default
bucket is `terraform-state`. Omit `--env` to process every env for that platform.

| Storage | CLI | Authentication |
|---------|-----|----------------|
| `s3` | `aws s3 cp` | AWS default credential chain, or `S3_ACCESS_KEY` and `S3_SECRET_ACCESS_KEY` |
| `r2` | `cf r2 objects put/get` | `cf auth login` or `CLOUDFLARE_API_TOKEN`; `CLOUDFLARE_ACCOUNT_ID` selects the account |
| `gcs` | `gcloud storage cp` | `GOOGLE_APPLICATION_CREDENTIALS`, otherwise the active gcloud account |

R2 requires the official Cloudflare `cf` CLI with R2 object read/write access.
Its authentication is independent of Terraform's S3 backend credentials; see
[Cloudflare authentication](https://developers.cloudflare.com/cf/ci/#provide-credentials).
`--endpoint` is optional for S3, rejected for R2, and ignored for GCS.

```bash
# Preview without transferring files or invoking cf; R2 preview needs no login.
rtk proxy ./scripts/tfvars-sync.sh upload --platform vultr --env logic3579 --storage r2 --dry-run

# After cf authentication, upload or download one environment.
rtk proxy ./scripts/tfvars-sync.sh upload --platform vultr --env logic3579 --storage r2
rtk proxy ./scripts/tfvars-sync.sh download --platform vultr --env logic3579 --storage r2

# Sync all GCP environments to a selected GCS bucket.
rtk proxy ./scripts/tfvars-sync.sh upload --platform gcp --storage gcs --bucket my-tfvars-bucket
```

Downloads overwrite the local tfvars; preserve local edits first. R2 downloads
write to a temporary file and replace tfvars only after success. Missing local
tfvars are skipped on upload. The script does not sync Terraform state or
backend configuration, and the sync bucket may differ from the state bucket.

## Resources covered

| Platform   | Provider                                              | Modules                                                                 |
|------------|-------------------------------------------------------|--------------------------------------------------------------------------|
| GCP        | `hashicorp/google` + `hashicorp/google-beta` `~> 7.0` | network, nat, iam, storage, compute, lb, neg-lb, gke                    |
| AWS        | `hashicorp/aws` `~> 5.0`                              | network, iam, compute (EC2 + EIP + key pair), rds (with SSM SecureString), lambda (Function URL), budget |
| Proxmox VE | `bpg/proxmox` `~> 0.104.0`                            | network (Linux bridges), storage (download_file), compute (KVM VMs)      |
| OpenStack  | `terraform-provider-openstack/openstack` `~> 3.4`     | network (networks/subnets/routers/SGs/FIPs), compute (instances/keypairs), storage (Cinder volumes) |
| Vultr      | `vultr/vultr` `~> 2.31`                               | network (VPC + firewall groups/rules), compute (instances + SSH keys + startup scripts) |

## Clean up

From any env directory:

```bash
terraform destroy
```

## Notes

- Always `terraform plan` before applying.
- `*.tfvars` and `*.tfstate` are gitignored — use `<platform>/envs/terraform.tfvars.example` as the template.
- `.cloudflare/` is local CLI cache and is also gitignored. Keep provider lockfiles tracked.
- Be mindful of cloud costs.
- See [AGENTS.md](AGENTS.md) for project conventions and module architecture.
