# AWS Terraform Infrastructure

Three-layer modular architecture mirroring the GCP side of this repository.

## Architecture

```
aws/
├── modules/           # Reusable modules
│   └── network/       # VPC, subnets, IGW, NAT, route tables, security groups
├── _shared/           # Shared variable/output declarations (symlinked by envs)
├── envs/              # Environment configurations
│   ├── dev/           # Dev environment (replicate to test/uat/prod as needed)
│   └── terraform.tfvars.example
├── main.tf            # Root module — wires submodules together
├── variables.tf       # Full type definitions with validations
├── outputs.tf         # Forwards module outputs
└── versions.tf        # Terraform + provider version constraints
```

### Layers

1. **Modules** (`modules/network/`) — Reusable resources with `flatten()` + `for_each` over compound keys. Each module: `main.tf` + `variables.tf` + `outputs.tf` + `versions.tf`.

2. **Root module** (`main.tf`) — Wires modules together. Contains cross-module reference resolution in `locals` when needed.

3. **Environment configs** (`envs/<env>/`) — Provider, backend, and root module call. `variables.tf` and `outputs.tf` are **symlinks** to `_shared/` — do not edit them in env dirs. `envs/dev/` is the included example; copy it to `envs/test/`, `envs/prod/`, etc. as needed.

## Usage

```bash
# Initialize (with S3 backend)
cd aws/envs/dev
terraform init -backend-config=backend.hcl

# Or initialize with local state (no backend)
terraform init

# Plan and apply
terraform plan
terraform apply

# Validate and format
terraform validate
terraform fmt -check -recursive ../../
```

## Network Module

### Resources

| AWS Resource | Purpose | Compound Key |
|---|---|---|
| `aws_vpc` | Virtual Private Cloud | `vpc.name` |
| `aws_subnet` | Public/private subnets | `vpc-name/subnet-name` |
| `aws_internet_gateway` | Internet access for public subnets | `vpc.name` |
| `aws_eip` + `aws_nat_gateway` | Outbound internet for private subnets | `vpc-name/nat-name` |
| `aws_route_table` | Public (per VPC) and private (per NAT) | — |
| `aws_security_group` | Stateful firewall rules | `vpc-name/sg-name` |
| `aws_vpc_security_group_*_rule` | Individual SG rules | `vpc-name/sg-name/index` |

### Routing Design

- **Public subnets** (`public = true`) share one route table per VPC with `0.0.0.0/0 → IGW`
- **Private subnets with NAT** (`nat_gateway_name = "nat-1a"`) get a route table with `0.0.0.0/0 → NAT GW`
- **Isolated subnets** (no `public`, no `nat_gateway_name`) use the VPC default route table

### HA Pattern

For production high availability, deploy NAT gateways in each AZ:

```hcl
subnets = [
  { name = "public-1a",  ..., availability_zone = "us-east-1a", public = true },
  { name = "public-1b",  ..., availability_zone = "us-east-1b", public = true },
  { name = "private-1a", ..., availability_zone = "us-east-1a", nat_gateway_name = "nat-1a" },
  { name = "private-1b", ..., availability_zone = "us-east-1b", nat_gateway_name = "nat-1b" },
]

nat_gateways = [
  { name = "nat-1a", subnet_name = "public-1a" },
  { name = "nat-1b", subnet_name = "public-1b" },
]
```

## Provider Versions

- Terraform `~> 1.5`
- `hashicorp/aws` `~> 5.0`
