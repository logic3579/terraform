# GCP Terraform Infrastructure

This directory contains Terraform configurations for managing GCP infrastructure across multiple environments.

## 🚀 Quick Start

### Prerequisites

1. **GCP Project**: Ensure you have a GCP project created
2. **GCS Bucket for State**: Create a GCS bucket for Terraform state storage
3. **gcloud CLI**: Install and configure [gcloud CLI](https://cloud.google.com/sdk/docs/install)
4. **Terraform**: Install [Terraform](https://www.terraform.io/downloads) (v1.0+)

### ⚠️ Important: Configure GCS Backend First

**Before running any Terraform commands**, you must configure the GCS backend for state management.

1. Create a GCS bucket for Terraform state:

   ```bash
   gsutil mb -p YOUR_PROJECT_ID -l REGION gs://YOUR-TERRAFORM-STATE-BUCKET

   # Enable versioning (recommended)
   gsutil versioning set on gs://YOUR-TERRAFORM-STATE-BUCKET
   ```

2. Update the backend configuration in each environment's `main.tf`:

   ```hcl
   terraform {
     backend "gcs" {
       bucket = "YOUR-TERRAFORM-STATE-BUCKET"  # ← Change this
       prefix = "gcp/ENVIRONMENT"              # ← Change ENVIRONMENT (dev/test/prod)
     }
   }
   ```

3. Initialize Terraform:
   ```bash
   cd gcp/envs/YOUR_ENVIRONMENT
   terraform init
   ```

---

## 📁 Directory Structure

```
gcp/
├── README.md                    # This file
├── main.tf                      # Root module - wires submodules together
├── variables.tf                 # Root module variables
├── outputs.tf                   # Root module outputs
├── modules/                     # Reusable Terraform modules
│   ├── network/                 # VPC, subnets, firewalls
│   ├── nat/                     # Cloud NAT and Router
│   ├── gce/                     # Compute Engine VMs and instance groups
│   ├── iam/                     # Service accounts and IAM
│   ├── gcs/                     # Cloud Storage buckets
│   └── lb/                      # Load Balancers (HTTP/HTTPS)
└── envs/                        # Environment-specific configurations
    ├── terraform.tfvars.example # Template for tfvars
    ├── dev/                     # Development environment
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── outputs.tf
    │   └── terraform.tfvars     # Dev-specific values (gitignored)
    ├── test/                    # Test environment
    │   └── ...
    └── prod/                    # Production environment
        └── ...
```

---

## 🏗️ Modules Overview

### Network Module (`modules/network/`)

Manages VPC networks, subnets, and firewall rules.

**Resources**:

- `google_compute_network` - VPC network
- `google_compute_subnetwork` - Subnets
- `google_compute_firewall` - Firewall rules

**Key Features**:

- Multi-region subnet support
- Flexible firewall rule configuration
- Private Google Access enabled by default

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

### GCE Module (`modules/gce/`)

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

### IAM Module (`modules/iam/`)

Manages service accounts and IAM bindings.

**Resources**:

- `google_service_account` - Service accounts
- `google_project_iam_member` - IAM role bindings

**Key Features**:

- Uses `google_project_iam_member` (not `binding`) to avoid conflicts
- Supports multiple roles per service account

### GCS Module (`modules/gcs/`)

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

## 🌍 Multi-Environment Management

### Switching Between Environments

Each environment (dev/test/prod) typically uses a different GCP project. Use `gcloud` to switch contexts:

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
# Working with TEST environment
cd gcp/envs/test
cp ../terraform.tfvars.example terraform.tfvars
gcloud config set project my-project-test
terraform init
terraform plan
terraform apply

# Switching to PROD environment
cd ../prod
cp ../terraform.tfvars.example terraform.tfvars
gcloud config set project my-project-prod
terraform init
terraform plan
terraform apply
```

### Environment-Specific Configuration

Each environment has its own `terraform.tfvars` file with environment-specific values:

- **dev**: Development environment (smaller instances, fewer resources)
- **test**: Testing environment (similar to prod but isolated)
- **prod**: Production environment (full-scale resources)

---

## 🛠️ Common Terraform Commands

### Initialization

```bash
# Initialize Terraform (downloads providers, sets up backend)
terraform init

# Reinitialize after backend changes
terraform init -reconfigure

# Migrate state to a new backend
terraform init -migrate-state
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
terraform state show 'module.gcp.module.gce.google_compute_instance.this["vm-name"]'

# Remove a resource from state (doesn't delete the actual resource)
terraform state rm 'module.gcp.module.gce.google_compute_instance.this["vm-name"]'

# Move a resource in state (rename)
terraform state mv 'module.old.resource' 'module.new.resource'

# Pull current state
terraform state pull > terraform.tfstate.backup

# Push state (use with caution!)
terraform state push terraform.tfstate
```

### Importing Existing Resources

```bash
# Import a VM instance
terraform import 'module.gcp.module.gce.google_compute_instance.this["vm-name"]' \
  projects/PROJECT_ID/zones/ZONE/instances/INSTANCE_NAME

# Import a subnet
terraform import 'module.gcp.module.network.google_compute_subnetwork.this["subnet-name"]' \
  projects/PROJECT_ID/regions/REGION/subnetworks/SUBNET_NAME

# Import a load balancer forwarding rule
terraform import 'module.gcp.module.lb.google_compute_global_forwarding_rule.http["lb-name"]' \
  projects/PROJECT_ID/global/forwardingRules/RULE_NAME
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
terraform destroy -target=module.gcp.module.gce.google_compute_instance.this["vm-name"]

# Preview what would be destroyed
terraform plan -destroy
```

### Workspace Management

```bash
# List workspaces
terraform workspace list

# Create a new workspace
terraform workspace new WORKSPACE_NAME

# Switch workspace
terraform workspace select WORKSPACE_NAME

# Show current workspace
terraform workspace show
```

---

## 🔧 Troubleshooting

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

## 📝 Best Practices

### 1. State Management

- ✅ Always use remote state (GCS backend)
- ✅ Enable versioning on state bucket
- ✅ Never edit state files manually
- ✅ Use state locking to prevent concurrent modifications

### 2. Code Organization

- ✅ Use modules for reusable components
- ✅ Keep environment-specific values in `terraform.tfvars`
- ✅ Use meaningful resource names
- ✅ Add comments for complex configurations

### 3. Security

- ✅ Never commit `terraform.tfvars` to git (use `.gitignore`)
- ✅ Use service accounts with minimal permissions
- ✅ Rotate credentials regularly
- ✅ Use GCP-managed SSL certificates when possible

### 4. Change Management

- ✅ Always run `terraform plan` before `apply`
- ✅ Review plans carefully, especially for production
- ✅ Use `-target` for surgical changes
- ✅ Test changes in dev/test before prod

### 5. Lifecycle Management

- ✅ Use `lifecycle` blocks to prevent accidental deletions
- ✅ Use `ignore_changes` for externally managed attributes
- ✅ Tag resources for cost tracking and organization

---

## 🔍 Common Use Cases

### Adding a New VM Instance

1. Add configuration to `terraform.tfvars`:

   ```hcl
   vm_instances = [
     # ... existing VMs ...
     {
       name                  = "new-vm"
       machine_type          = "e2-medium"
       zone                  = "asia-southeast1-a"
       region                = "asia-southeast1"
       image_family          = "ubuntu-2204-lts"
       image_project         = "ubuntu-os-cloud"
       disk_size             = 100
       disk_type             = "pd-standard"
       network_tags          = ["web-server"]
       external_ip           = true
       network               = "my-vpc"
       subnetwork            = "my-subnet"
       service_account_email = "PROJECT_NUMBER-compute@developer.gserviceaccount.com"
     }
   ]
   ```

2. Apply changes:
   ```bash
   terraform plan
   terraform apply
   ```

### Importing Existing Infrastructure

See the [Importing Existing Resources](#importing-existing-resources) section above for detailed import commands.

### Updating Load Balancer Configuration

1. Modify `load_balancers` in `terraform.tfvars`
2. Run `terraform plan` to preview changes
3. Apply changes: `terraform apply`

### Managing Multiple Environments

Use separate directories for each environment and switch GCP projects:

```bash
# Development
cd gcp/envs/dev
gcloud config set project my-project-dev
terraform apply

# Test
cd gcp/envs/test
gcloud config set project my-project-test
terraform apply

# Production
cd gcp/envs/prod
gcloud config set project my-company-prod
terraform apply
```

---

## 📚 Additional Resources

- [Terraform GCP Provider Documentation](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [GCP Best Practices](https://cloud.google.com/docs/terraform/best-practices-for-terraform)
- [Terraform Best Practices](https://www.terraform.io/docs/cloud/guides/recommended-practices/index.html)
- [GCP Networking Overview](https://cloud.google.com/vpc/docs/vpc)

---

## 🆘 Getting Help

If you encounter issues:

1. Check the [Troubleshooting](#troubleshooting) section
2. Review Terraform logs (`TF_LOG=DEBUG`)
3. Consult the [GCP Provider Documentation](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
4. Check GCP Console for resource status

---

## 📄 License
