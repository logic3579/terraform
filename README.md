# Terraform Infrastructure as Code

Terraform configurations for provisioning infrastructure on **GCP**, **AWS**, **Proxmox VE**, and **OpenStack**.

## Structure

```
.
├── gcp/         # Google Cloud Platform — production-ready (8 modules)
├── aws/         # Amazon Web Services — network module complete
├── proxmox/     # Proxmox VE — basic VM/network/storage (bpg/proxmox)
└── openstack/   # OpenStack — basic compute/network/storage (terraform-provider-openstack)
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

## Usage

All commands run from the env directory.

### GCP

```bash
cd gcp/envs/devtest
cp ../terraform.tfvars.example terraform.tfvars   # then edit
terraform init -backend-config=backend.hcl
terraform plan
terraform apply
```

### AWS

```bash
cd aws/envs/devtest
cp ../terraform.tfvars.example terraform.tfvars   # then edit
terraform init -backend-config=backend.hcl        # or: terraform init -backend=false
terraform plan
terraform apply
```

### Proxmox VE

```bash
cd proxmox/envs/devtest
cp ../terraform.tfvars.example terraform.tfvars   # then edit
terraform init                                    # local backend
terraform plan
terraform apply
```

### OpenStack

```bash
cd openstack/envs/devtest
cp ../terraform.tfvars.example terraform.tfvars   # then edit

# State backend uses Swift's S3-compatible API
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...

terraform init -backend-config=backend.hcl
terraform plan
terraform apply
```

## Resources covered

| Platform   | Provider                                              | Modules                                                                 |
|------------|-------------------------------------------------------|--------------------------------------------------------------------------|
| GCP        | `hashicorp/google` + `hashicorp/google-beta` `~> 7.0` | network, nat, iam, storage, compute, lb, neg-lb, gke                    |
| AWS        | `hashicorp/aws` `~> 5.0`                              | network (VPC, subnets, IGW, NAT GW, route tables, security groups)       |
| Proxmox VE | `bpg/proxmox` `~> 0.104.0`                            | network (Linux bridges), storage (download_file), compute (KVM VMs)      |
| OpenStack  | `terraform-provider-openstack/openstack` `~> 3.4`     | network (networks/subnets/routers/SGs/FIPs), compute (instances/keypairs), storage (Cinder volumes) |

## Clean up

From any env directory:

```bash
terraform destroy
```

## Notes

- Always `terraform plan` before applying.
- `*.tfvars` and `*.tfstate` are gitignored — use `<platform>/envs/terraform.tfvars.example` as the template.
- Be mindful of cloud costs.
- See `CLAUDE.md` for module-by-module architecture details.
