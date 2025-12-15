# GCP Terraform Infrastructure

This directory contains Terraform configurations for managing GCP infrastructure across multiple environments.

## Quick Start

### Prerequisites

1. **GCP Project**: Ensure you have a GCP project created
2. **GCS Bucket for State**: Create a GCS bucket for Terraform state storage
3. **gcloud CLI**: Install and configure [gcloud CLI](https://cloud.google.com/sdk/docs/install)
4. **Terraform**: Install [Terraform](https://www.terraform.io/downloads) (v1.5+)

### Important: Configure GCS Backend First

**Before running any Terraform commands**, you must configure the GCS backend for state management.

1. Create a GCS bucket for Terraform state:

   ```bash
   gsutil mb -p YOUR_PROJECT_ID -l REGION gs://YOUR-TERRAFORM-STATE-BUCKET

   # Enable versioning (recommended)
   gsutil versioning set on gs://YOUR-TERRAFORM-STATE-BUCKET
   ```

2. Create `backend.hcl` in each environment directory:

   ```hcl
   # gcp/envs/devtest/backend.hcl
   bucket = "YOUR-TERRAFORM-STATE-BUCKET"
   prefix = "gcp/devtest"
   ```

3. Initialize Terraform with backend config:
   ```bash
   cd gcp/envs/YOUR_ENVIRONMENT
   terraform init -backend-config=backend.hcl
   ```

---

## Directory Structure

```
gcp/
├── README.md                    # This file
├── main.tf                      # Root module - wires submodules together
├── variables.tf                 # Root module variables (with full type definitions)
├── outputs.tf                   # Root module outputs
├── versions.tf                  # Terraform and provider version constraints
├── _shared/                     # Shared configuration templates
│   ├── variables.tf             # Shared variable declarations
│   ├── outputs.tf               # Shared output definitions
│   ├── providers.tf             # Provider configuration template
│   └── main.tf                  # Module call template
├── modules/                     # Reusable Terraform modules
│   ├── network/                 # VPC, subnets, firewalls (multi-VPC support)
│   ├── nat/                     # Cloud NAT and Router
│   ├── compute/                 # Compute Engine VMs and instance groups
│   ├── iam/                     # Service accounts and IAM
│   ├── storage/                 # Cloud Storage buckets
│   └── lb/                      # Load Balancers (HTTP/HTTPS)
├── scripts/                     # Startup scripts for VMs
│   └── install-docker.sh        # Docker installation script
└── envs/                        # Environment-specific configurations
    ├── terraform.tfvars.example # Template for tfvars
    ├── devtest/                 # Dev + Test environment (merged)
    │   ├── main.tf              # Provider and module configuration
    │   ├── variables.tf         # → symlink to ../../_shared/variables.tf
    │   ├── outputs.tf           # → symlink to ../../_shared/outputs.tf
    │   ├── backend.hcl          # Backend configuration
    │   └── terraform.tfvars     # Environment-specific values (gitignored)
    └── prod/                    # Production environment
        └── ...
```

---

## Environments

| Environment | Directory       | Description                                   |
| ----------- | --------------- | --------------------------------------------- |
| `devtest`   | `envs/devtest/` | Combined dev and test environment (multi-VPC) |
| `prod`      | `envs/prod/`    | Production environment                        |

### Multi-VPC Support

The `devtest` environment demonstrates multi-VPC management within a single Terraform configuration. This is useful when:

- Multiple VPCs exist in the same GCP project
- You want to manage dev and test resources together
- You need isolated networks with shared infrastructure code

---

## Shared Configuration (`_shared/`)

The `_shared/` directory contains shared configuration templates that are used via symlinks in each environment directory. This eliminates code duplication across environments.

### How It Works

Environment directories use **symlinks** to share common configurations:

```bash
# In each envs/*/
variables.tf → ../../_shared/variables.tf  # Symlink
outputs.tf   → ../../_shared/outputs.tf    # Symlink
main.tf      # Environment-specific (not symlinked)
backend.hcl  # Environment-specific backend config
```

### Setting Up Symlinks for a New Environment

```bash
cd gcp/envs/NEW_ENV
ln -s ../../_shared/variables.tf variables.tf
ln -s ../../_shared/outputs.tf outputs.tf
```

### Files in `_shared/`

| File           | Purpose                                          |
| -------------- | ------------------------------------------------ |
| `variables.tf` | Shared variable declarations (used via symlink)  |
| `outputs.tf`   | Shared output definitions (used via symlink)     |
| `providers.tf` | Provider configuration template (reference only) |
| `main.tf`      | Module call template (reference only)            |

---

## Modules Overview

### Network Module (`modules/network/`)

Manages VPC networks, subnets, and firewall rules with **multi-VPC support**.

**Resources**:

- `google_compute_network` - VPC networks (supports multiple)
- `google_compute_subnetwork` - Subnets
- `google_compute_firewall` - Firewall rules

**Key Features**:

- **Multi-VPC support**: Manage multiple VPCs in a single configuration
- Multi-region subnet support
- Flexible firewall rule configuration
- Private Google Access enabled by default

**Variable Structure**:

```hcl
networks = [
  {
    name = "vpc-1"
    subnets = [
      { name = "subnet-1", cidr = "10.0.0.0/24", region = "asia-southeast1" }
    ]
    firewalls = [
      { name = "allow-ssh", direction = "INGRESS", ... }
    ]
  },
  {
    name = "vpc-2"
    subnets   = []
    firewalls = []
  }
]
```

### NAT Module (`modules/nat/`)

Manages Cloud NAT for private instance internet access.

**Resources**:

- `google_compute_router` - Cloud Router
- `google_compute_router_nat` - Cloud NAT
- `google_compute_address` - External IP (for MANUAL_ONLY mode)

**Key Features**:

- AUTO_ONLY or MANUAL_ONLY IP allocation
- Configurable port allocation
- Logging support

### Compute Module (`modules/compute/`)

Manages Compute Engine VMs and instance groups.

**Resources**:

- `google_compute_instance` - VM instances
- `google_compute_address` - External IPs
- `google_compute_instance_group` - Instance groups

**Key Features**:

- Docker pre-installed via startup script
- External IP support
- Service account configuration
- Named ports for load balancing
- Shielded VM (secure boot enabled)
- Preemptible instance support

### IAM Module (`modules/iam/`)

Manages service accounts and IAM bindings.

**Resources**:

- `google_service_account` - Service accounts
- `google_project_iam_member` - IAM role bindings

**Key Features**:

- Uses `google_project_iam_member` (not `binding`) to avoid conflicts
- Supports multiple roles per service account

### Storage Module (`modules/storage/`)

Manages Cloud Storage buckets.

**Resources**:

- `google_storage_bucket` - Storage buckets

**Key Features**:

- Versioning support
- Lifecycle rules
- Uniform bucket-level access
- Public and private access

### Load Balancer Module (`modules/lb/`)

Manages HTTP(S) Load Balancers.

**Resources**:

- `google_compute_global_address` - Global IP
- `google_compute_health_check` - Health checks (TCP)
- `google_compute_backend_service` - Backend services
- `google_compute_url_map` - URL maps
- `google_compute_target_http_proxy` - HTTP proxies
- `google_compute_target_https_proxy` - HTTPS proxies
- `google_compute_managed_ssl_certificate` - Managed SSL certificates
- `google_compute_global_forwarding_rule` - Forwarding rules

**Key Features**:

- HTTP and HTTPS support
- GCP-managed or self-managed SSL certificates
- Session affinity (CLIENT_IP)
- Cloud Armor integration
- Logging support
- New Application Load Balancer (EXTERNAL_MANAGED)

---

## Variable Reference

### Core Variables

| Variable     | Type        | Description                                     |
| ------------ | ----------- | ----------------------------------------------- |
| `env`        | string      | Environment name: dev, test, devtest, uat, prod |
| `labels`     | map(string) | Labels applied to all resources                 |
| `project_id` | string      | GCP project ID                                  |
| `region`     | string      | Default GCP region                              |
| `zone`       | string      | Default GCP zone                                |

### Network Variables

| Variable   | Type         | Description                                           |
| ---------- | ------------ | ----------------------------------------------------- |
| `networks` | list(object) | List of VPC configurations with subnets and firewalls |

**`networks` Object Structure**:

```hcl
{
  name = string                    # VPC name
  subnets = list(object({          # Optional, default: []
    name   = string
    cidr   = string
    region = string
  }))
  firewalls = list(object({        # Optional, default: []
    name                    = string
    description             = optional(string)
    direction               = string  # INGRESS or EGRESS
    priority                = optional(number)
    source_ranges           = optional(list(string))
    destination_ranges      = optional(list(string))
    source_tags             = optional(list(string))
    target_tags             = optional(list(string))
    target_service_accounts = optional(list(string))
    allow = list(object({
      protocol = string
      ports    = optional(list(string))
    }))
    disabled = optional(bool)
  }))
}
```

### Other Variables

| Variable           | Description                            |
| ------------------ | -------------------------------------- |
| `nats`             | List of NAT configurations             |
| `buckets`          | List of GCS bucket configurations      |
| `instances`        | List of VM instance configurations     |
| `instance_groups`  | List of instance group configurations  |
| `load_balancers`   | List of load balancer configurations   |
| `service_accounts` | List of service account configurations |
| `iam_bindings`     | List of IAM binding configurations     |

---

## Multi-Environment Management

### Switching Between Environments

Each environment may use a different GCP project. Use `gcloud` to switch contexts:

```bash
# List available projects
gcloud projects list

# Switch to a specific project
gcloud config set project YOUR_PROJECT_ID

# Verify current project
gcloud config get-value project
```

### Example Workflow

```bash
# Working with DEVTEST environment
cd gcp/envs/devtest
gcloud config set project my-project-test
terraform init -backend-config=backend.hcl
terraform plan
terraform apply

# Switching to PROD environment
cd ../prod
gcloud config set project my-company-prod
terraform init -backend-config=backend.hcl
terraform plan
terraform apply
```

---

## Common Terraform Commands

### Initialization

```bash
# Initialize Terraform with backend configuration
terraform init -backend-config=backend.hcl

# Upgrade providers to latest compatible version
terraform init -upgrade -backend-config=backend.hcl

# Reinitialize after backend changes
terraform init -reconfigure -backend-config=backend.hcl

# Migrate state to a new backend
terraform init -migrate-state -backend-config=backend.hcl
```

### Planning and Applying

```bash
# Preview changes
terraform plan

# Preview with detailed output
terraform plan -out=tfplan

# Apply changes
terraform apply

# Apply without confirmation prompt
terraform apply -auto-approve

# Apply a saved plan
terraform apply tfplan

# Target specific resources
terraform apply -target=module.gcp.module.network
```

### State Management

```bash
# List resources in state
terraform state list

# Show details of a specific resource
terraform state show 'module.gcp.module.compute.google_compute_instance.this["vm-name"]'

# Remove a resource from state (doesn't delete the actual resource)
terraform state rm 'module.gcp.module.compute.google_compute_instance.this["vm-name"]'

# Move a resource in state (rename)
terraform state mv 'module.old.resource' 'module.new.resource'

# Pull current state
terraform state pull > terraform.tfstate.backup

# Push state (use with caution!)
terraform state push terraform.tfstate
```

### Importing Existing Resources

```bash
# Import a VPC network
terraform import 'module.gcp.module.network.google_compute_network.this["vpc-name"]' \
  projects/PROJECT_ID/global/networks/VPC_NAME

# Import a subnet (note the new key format: "vpc-name/subnet-name")
terraform import 'module.gcp.module.network.google_compute_subnetwork.this["vpc-name/subnet-name"]' \
  projects/PROJECT_ID/regions/REGION/subnetworks/SUBNET_NAME

# Import a firewall rule
terraform import 'module.gcp.module.network.google_compute_firewall.this["vpc-name/firewall-name"]' \
  projects/PROJECT_ID/global/firewalls/FIREWALL_NAME

# Import a VM instance
terraform import 'module.gcp.module.compute.google_compute_instance.this["vm-name"]' \
  projects/PROJECT_ID/zones/ZONE/instances/INSTANCE_NAME

# Import a GCS bucket
terraform import 'module.gcp.module.storage.google_storage_bucket.this["bucket-name"]' \
  PROJECT_ID/BUCKET_NAME
```

### Validation and Formatting

```bash
# Validate configuration
terraform validate

# Format code
terraform fmt

# Format recursively
terraform fmt -recursive

# Check formatting (CI/CD)
terraform fmt -check
```

### Destroying Resources

```bash
# Destroy all resources (use with extreme caution!)
terraform destroy

# Destroy specific resources
terraform destroy -target=module.gcp.module.compute.google_compute_instance.this["vm-name"]

# Preview what would be destroyed
terraform plan -destroy
```

---

## Troubleshooting

### State Lock Issues

If you encounter a state lock error:

```bash
# View lock info
terraform force-unlock LOCK_ID

# Force unlock (use carefully!)
terraform force-unlock -force LOCK_ID
```

### Backend Configuration Issues

```bash
# Reconfigure backend
terraform init -reconfigure

# Migrate state
terraform init -migrate-state
```

### Resource Already Exists

If Terraform tries to create a resource that already exists:

```bash
# Import the existing resource
terraform import 'RESOURCE_ADDRESS' RESOURCE_ID

# Or remove from configuration and let Terraform manage it separately
```

### Drift Detection

```bash
# Detect configuration drift
terraform plan -refresh-only

# Apply drift corrections
terraform apply -refresh-only
```

### Debugging

```bash
# Enable debug logging
export TF_LOG=DEBUG
terraform plan

# Log to file
export TF_LOG=DEBUG
export TF_LOG_PATH=terraform-debug.log
terraform plan

# Disable logging
unset TF_LOG
unset TF_LOG_PATH
```

---

## Best Practices

### 1. State Management

- Always use remote state (GCS backend)
- Enable versioning on state bucket
- Never edit state files manually
- Use state locking to prevent concurrent modifications

### 2. Code Organization

- Use modules for reusable components
- Keep environment-specific values in `terraform.tfvars`
- Use meaningful resource names
- Add comments for complex configurations

### 3. Security

- Never commit `terraform.tfvars` to git (use `.gitignore`)
- Use service accounts with minimal permissions
- Rotate credentials regularly
- Use GCP-managed SSL certificates when possible
- Restrict SSH access to IAP ranges only

### 4. Change Management

- Always run `terraform plan` before `apply`
- Review plans carefully, especially for production
- Use `-target` for surgical changes
- Test changes in devtest before prod

### 5. Lifecycle Management

- Use `lifecycle` blocks to prevent accidental deletions
- Use `ignore_changes` for externally managed attributes
- Tag resources for cost tracking and organization

---

## Module Renaming and State Migration

If you need to migrate resources after module or variable structure changes, use `terraform state mv`.

### Important Notes

- Run state migration commands for **each environment** separately
- Always backup state before migration: `terraform state pull > backup.tfstate`
- Verify with `terraform plan` after migration (should show no resource recreation)

---

## Additional Resources

- [Terraform GCP Provider Documentation](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [GCP Best Practices](https://cloud.google.com/docs/terraform/best-practices-for-terraform)
- [Terraform Best Practices](https://www.terraform.io/docs/cloud/guides/recommended-practices/index.html)
- [GCP Networking Overview](https://cloud.google.com/vpc/docs/vpc)

---

## Getting Help

If you encounter issues:

1. Check the [Troubleshooting](#troubleshooting) section
2. Review Terraform logs (`TF_LOG=DEBUG`)
3. Consult the [GCP Provider Documentation](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
4. Check GCP Console for resource status
