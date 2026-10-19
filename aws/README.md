# AWS Terraform Infrastructure

Three-layer modular architecture mirroring the GCP side of this repository.

## Architecture

```
aws/
├── modules/           # Reusable modules
│   ├── network/       # VPC, subnets, IGW, NAT, route tables, security groups
│   ├── iam/           # EC2 instance profiles, Lambda execution roles, IAM users
│   ├── compute/       # EC2 instances, key pairs, optional Elastic IPs
│   ├── rds/           # RDS instances + DB subnet groups + SSM SecureString master password
│   ├── lambda/        # Lambda functions packaged from a local source dir, optional Function URL
│   └── budget/        # AWS Budgets with email notifications
├── _shared/           # Shared variable/output declarations (symlinked by envs)
├── envs/              # Environment configurations
│   ├── example/       # Reusable example project (S3-compatible backend)
│   │   ├── main.tf
│   │   ├── variables.tf  # → ../../_shared/variables.tf
│   │   ├── outputs.tf    # → ../../_shared/outputs.tf
│   │   ├── backend.hcl.example
│   │   └── terraform.tfvars.example
│   └── logic3579/     # Personal project (Cloudflare R2 backend)
├── main.tf            # Root module — wires submodules together
├── variables.tf       # Full type definitions with validations
├── outputs.tf         # Forwards module outputs
└── versions.tf        # Terraform + provider version constraints
```

### Layers

1. **Modules** (`modules/<name>/`) — Reusable resources with `flatten()` + `for_each` over compound keys. Each module: `main.tf` + `variables.tf` + `outputs.tf` + `versions.tf`.

2. **Root module** (`main.tf`) — Wires modules together. Threads `module.network` subnet/SG ID maps into `compute` / `rds`, and `module.iam` instance-profile / role ARN maps into `compute` / `lambda`.

3. **Project configs** (`envs/<project>/`) — Provider, backend, and root module call. `variables.tf` and `outputs.tf` are **symlinks** to `_shared/` — do not edit them in project dirs. Only `example` and `logic3579` are tracked. Create other projects locally by copying `example/main.tf` and recreating the symlinks; their directories are gitignored.

Manually back up and restore each local project's `terraform.tfvars` and
`backend.hcl` outside Git. On another machine, recreate the project entrypoint,
restore both files and provider authentication, and initialize the same backend.
See the [backup workflow](../README.md#local-projects-and-manual-backups).
The directory name does not change the `env` value in tfvars.

## Usage

Use `example` as a source template. From the repository root, create a new
project directory and copy only its configuration:

```bash
project=my-project
rtk proxy mkdir "aws/envs/$project"
rtk proxy cp aws/envs/example/main.tf "aws/envs/$project/main.tf"
rtk proxy ln -s ../../_shared/variables.tf "aws/envs/$project/variables.tf"
rtk proxy ln -s ../../_shared/outputs.tf "aws/envs/$project/outputs.tf"
rtk proxy cp aws/envs/example/terraform.tfvars.example "aws/envs/$project/terraform.tfvars"
rtk proxy cp aws/envs/example/backend.hcl.example "aws/envs/$project/backend.hcl"
```

Edit the new project's tfvars: set `env`, `region`, authentication such as
`aws_profile`, and the required resource inputs; remove unneeded examples.
The current example forwards only `vpcs` to the root module. Add the appropriate
input forwarding in your new project's `module "aws"` block before managing
IAM, EC2, RDS, Lambda, or budgets. The personal entrypoint demonstrates broader
wiring but also omits `iam_users`. Back up a customized `main.tf` with your inputs.

The `aws/envs/example/` directory includes `backend.hcl.example` — a template for
pointing the S3 backend at **Cloudflare R2** (any S3-compatible store works
the same way). All per-project `backend.hcl` files are already gitignored.
`envs/logic3579/backend.hcl` is local personal configuration, supplied separately.

Set a unique backend key such as `aws/my-project/terraform.tfstate` in the new
project. The bucket must already exist. For native S3, replace the R2 settings
with the AWS bucket region and authentication and remove R2-specific settings.
Keep provider authentication separate from R2 backend credentials.

For SSO, set the matching `aws_profile` in tfvars and log in before initialization.
Continue from the repository root:

```bash
rtk proxy aws sso login --profile your-profile
rtk proxy terraform -chdir="aws/envs/$project" init -backend-config=backend.hcl
rtk proxy terraform -chdir="aws/envs/$project" validate
rtk proxy terraform -chdir="aws/envs/$project" plan
```

Review the plan before `rtk proxy terraform -chdir="aws/envs/$project" apply`.
Keep `example` as the source template. See the root
[backup/restore workflow](../README.md#local-projects-and-manual-backups) and
[Git ignore rules](../README.md#git-ignore-rules) for local projects.

For SSO users on AWS CLI ≥ 2.27 (new `aws login` writing to `~/.aws/login/`),
the Go SDK can't read that cache directly — bridge it via a `[profile terraform]`
in `~/.aws/config` with `credential_process = aws configure export-credentials
--profile default --format process`, then set `aws_profile = "terraform"` in tfvars.

## Modules

### Network Module

#### Resources

| AWS Resource | Purpose | Compound Key |
|---|---|---|
| `aws_vpc` | Virtual Private Cloud | `vpc.name` |
| `aws_subnet` | Public/private subnets | `vpc-name/subnet-name` |
| `aws_internet_gateway` | Internet access for public subnets | `vpc.name` |
| `aws_eip` + `aws_nat_gateway` | Outbound internet for private subnets | `vpc-name/nat-name` |
| `aws_route_table` + `aws_route` + `aws_route_table_association` | Public (per VPC) and private (per NAT) | — |
| `aws_security_group` | Stateful firewall rules | `vpc-name/sg-name` |
| `aws_vpc_security_group_ingress_rule` / `_egress_rule` | Individual SG rules | `vpc-name/sg-name/index` |

#### Routing Design

- **Public subnets** (`public = true`) share one route table per VPC with `0.0.0.0/0 → IGW`
- **Private subnets with NAT** (`nat_gateway_name = "nat-1a"`) get a route table with `0.0.0.0/0 → NAT GW`
- **Isolated subnets** (no `public`, no `nat_gateway_name`) use the VPC default route table

#### HA Pattern

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

#### Caveats

- SG rule resources (`aws_vpc_security_group_*_rule`) only honor `cidr_blocks[0]` — split per CIDR for full coverage.
- SG rules auto-null `from_port` / `to_port` when `protocol = "-1"` (AWS rejects the combination).

### IAM Module

#### Resources

| AWS Resource | Purpose | Compound Key |
|---|---|---|
| `aws_iam_role` (EC2) + `aws_iam_instance_profile` | One role + one instance profile per entry (same name) | `ec2_instance_profile.name` |
| `aws_iam_role` (Lambda) | Lambda execution roles | `lambda_execution_role.name` |
| `aws_iam_role_policy_attachment` | Managed policies attached to roles | `role-name/policy-arn` |
| `aws_iam_role_policy` | Inline policies on roles | `role-name/policy-name` |
| `aws_iam_user` | Standalone IAM users | `user.name` |
| `aws_iam_user_policy_attachment` | Managed policies attached to users | `user-name/policy-arn` |
| `aws_iam_user_policy` | Inline policies on users | `user-name/policy-name` |

#### Inputs

- `ec2_instance_profiles` — produces one role + one instance profile per entry (same name) with EC2 trust policy.
- `lambda_execution_roles` — produces one role per entry with Lambda trust policy.
- `iam_users` — produces standalone IAM users with optional `path` and `permissions_boundary`.

All three support `managed_policy_arns` (list) and `inline_policies` (map of policy-name → JSON document).

#### Outputs

Maps consumed by the root module to wire other modules:

- `ec2_instance_profile_names` — `alias → profile name` (used by `compute.iam_instance_profile_names`)
- `ec2_role_arns` — `alias → role ARN`
- `lambda_role_arns` — `alias → role ARN` (used by `lambda.lambda_role_arns`)
- `iam_user_arns` — `user name → ARN`
- `iam_user_names` — `alias → user name`

#### Caveats

- Console passwords (`aws_iam_user_login_profile`) and programmatic access keys (`aws_iam_access_key`) are **intentionally not managed here** — they end up in Terraform state in cleartext. Create them out-of-band (console or CLI) and store the secrets in SSM Parameter Store / Secrets Manager.
- IAM is global — `var.region` does not affect IAM resources, but every other module in the root call still requires it.

### Compute Module

#### Resources

| AWS Resource | Purpose | Compound Key |
|---|---|---|
| `aws_key_pair` | SSH key pairs registered in this region | `key_pair.name` |
| `aws_instance` | EC2 instances | `instance.name` |
| `aws_eip` | Optional Elastic IPs (per-instance) | `instance.name` (only when `eip = true`) |
| `data.aws_ami` | AMI lookup per `os` preset | `instance.name` (only when `os` is set and `ami_id` is not) |

#### Key features

- **AMI lookup presets** — set `os` to `debian-12`, `al2023`, or `ubuntu-22` for an automatic `data.aws_ami` lookup; or set `ami_id` directly to bypass it.
- **Network references by name** — `subnet_name` and `security_group_names` use the network module's compound keys (`vpc-name/subnet-name`).
- **Instance profile by alias** — `iam_instance_profile` references a key from the iam module's `ec2_instance_profile_names` output.
- **IMDSv2 required** — `http_tokens = "required"`, `http_put_response_hop_limit = 2`, applied unconditionally.
- **Encrypted root volume by default** — `gp3` / 30 GiB / `encrypted = true`.
- **`user_data` ignored on in-place changes** — to avoid replace-on-rerun. Bake config into the AMI or use SSM for post-boot changes.
- **Elastic IP optional** — set `eip = true` to allocate and attach.

### RDS Module

#### Resources

| AWS Resource | Purpose | Compound Key |
|---|---|---|
| `random_password` | Master password (24 chars, special-set restricted) | `rds.name` |
| `aws_ssm_parameter` | SecureString storing the master password | `rds.name` |
| `aws_db_subnet_group` | DB subnet group (≥2 AZs required) | `rds.name` |
| `aws_db_instance` | RDS instance | `rds.name` |

#### Key features

- **Master password** — randomly generated by `random_password` and written to SSM Parameter Store at `ssm_password_path` (default `/<name>/master_password`) as a `SecureString`. The plaintext is in Terraform state — encrypt state at rest.
- **Subnet group** — `subnet_names` must reference subnets in ≥2 AZs (RDS requirement). Use the network module's compound keys.
- **Engine version drift** — `engine_version` is in `ignore_changes` so AWS-side minor upgrades don't trigger replacement.
- **Supported engines** — `postgres`, `mysql`, `mariadb` (validated).

### Lambda Module

#### Resources

| AWS Resource | Purpose | Compound Key |
|---|---|---|
| `data.archive_file` | Zips the local `source_dir` | `function.name` |
| `aws_lambda_function` | Lambda function | `function.name` |
| `aws_lambda_function_url` | Optional public Function URL | `function.name` (only when `function_url.enabled`) |

#### Key features

- **Source packaging** — `source_dir` is resolved relative to `path.root` (the env dir), e.g. `source_dir = "lambda-src"` reads from `envs/<env>/lambda-src/`. The zip is written to `${path.root}/.terraform/tmp/<name>.zip`.
- **Execution role** — `role_name` references a key from the iam module's `lambda_role_arns` output.
- **Function URL** — optional, with `NONE` or `AWS_IAM` auth and optional CORS block.
- **Architecture** — `x86_64` or `arm64` (validated).
- Provided by the `hashicorp/archive` provider (`~> 2.4`).

### Budget Module

#### Resources

| AWS Resource | Purpose | Compound Key |
|---|---|---|
| `aws_budgets_budget` | One budget per entry with one or more notifications | `budget.name` |

#### Key features

- **Time units** — `DAILY`, `MONTHLY`, `QUARTERLY`, `ANNUALLY` (validated).
- **Notification thresholds** — `PERCENTAGE` (of `limit_amount`) or `ABSOLUTE_VALUE`.
- **Notification type** — `ACTUAL` or `FORECASTED`.
- **Subscribers** — list of email addresses per notification. AWS sends a one-time "Confirm subscription" email; recipients must click it before alerts start firing.
- **Cost filters** — `cost_filters = { Service = ["Amazon EC2"] }` etc.

## State backends

- Projects created from `envs/example/` use an S3 backend; the backend template targets R2. Set the new project's bucket, unique key, endpoint, and credentials before init.
- `envs/logic3579/` uses an S3 backend pointed at **Cloudflare R2** via `endpoints.s3` + skip flags. The `backend.hcl` embeds R2 credentials directly (gitignored). No DynamoDB locking on R2 — Terraform 1.10+'s native S3 lockfile (`use_lockfile = true`) is the alternative.

State key pattern: `aws/<env_name>/terraform.tfstate`.

## Provider Versions

- Terraform `~> 1.5`
- `hashicorp/aws` `~> 5.0`
- `hashicorp/archive` `~> 2.4` (Lambda source packaging)
- `hashicorp/random` `~> 3.5` (RDS master password)
