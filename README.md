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
└── scripts/     # Project configuration upload/download for S3, R2, and GCS
```

Each platform follows the same three-layer architecture:

- **Root module** wires reusable submodules together.
- **`modules/`** — reusable submodules; one resource family per submodule (`main.tf` + `variables.tf` + `outputs.tf` + `versions.tf`).
- **`envs/<project>/`** — provider, backend, and module-call wiring per project. `variables.tf` and `outputs.tf` in project dirs are **symlinks** to `<platform>/_shared/`.

Only `envs/example/` (example configuration) and `envs/logic3579/` (personal
project) are tracked. All other project directories are local and gitignored.
Each `example` project includes its configuration entrypoint, shared symlinks,
and tracked input/backend templates. The directory name is independent of
input values such as `env`; example tfvars may still use `env = "dev"`.

The example project layout is:

```text
<platform>/envs/example/
├── main.tf
├── variables.tf              # → ../../_shared/variables.tf
├── outputs.tf                # → ../../_shared/outputs.tf
├── terraform.tfvars.example
└── backend.hcl.example       # Remote-state platforms; absent for Proxmox
```

Use `example` as the source template for a new project directory. Keep real
configuration, credentials, state, and Terraform operations in that new
directory. Proxmox uses local state and only needs the tfvars template.

## Git ignore rules

The project-directory rules in [.gitignore](.gitignore) are:

```gitignore
/*/envs/*/
!/*/envs/example/
!/*/envs/logic3579/
```

The first rule ignores every project directory under a platform's `envs/`.
The two exceptions allow tracking `example` as the template and `logic3579` as
the personal project. Every other project is ignored automatically; no
per-project ignore entry is needed.

The file rules `*.tfvars`, `*.tfvars.json`, `**/backend.hcl`, `*.tfstate`,
`*.tfstate.*`, `.terraform/`, `.cloudflare/`, and `**/keys/` still apply inside
the two allowed directories. The `.example` templates remain trackable, as do
provider lockfiles in allowed projects. Ignore rules do not remove files that
Git already tracks. Git does not back up ignored projects; preserve their
configuration using the [backup and restore workflow](#local-projects-and-manual-backups).

## Prerequisites

1. Install Terraform `~> 1.5` — [installation guide](https://learn.hashicorp.com/tutorials/terraform/install-cli).
2. Authenticate against the cloud you'll target:
   - **GCP**: [provider auth](https://registry.terraform.io/providers/hashicorp/google/latest/docs/guides/getting_started)
   - **AWS**: [provider auth](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/)
   - **Proxmox**: API token (`Datacenter → Permissions → API Tokens`) or username/password
   - **OpenStack**: Keystone v3 credentials; for state backend, also Swift EC2 creds (`openstack ec2 credentials create`)
   - **Vultr**: API key — generate at https://my.vultr.com/settings/#settingsapi, then `export VULTR_API_KEY=...`

## Usage

Run Terraform commands from the target project directory. The tracked projects
and state backends are:

| Platform | Projects | Backend | State prefix or key |
|----------|--------------|---------|---------------------|
| GCP | `example` | GCS | `gcp/<project>` prefix |
| GCP | `logic3579` | S3-compatible R2 | `gcp/logic3579/terraform.tfstate` |
| AWS | `example`, `logic3579` | S3-compatible | `aws/<project>/terraform.tfstate` |
| Proxmox | `example` | Local | `terraform.tfstate` in the project directory |
| OpenStack | `example` | S3-compatible Swift | `openstack/<project>/terraform.tfstate` |
| Vultr | `example`, `logic3579` | S3-compatible R2 | `vultr/<project>/terraform.tfstate` |

For remote backends, copy `<platform>/envs/example/backend.hcl.example` to the env
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

### Create a project from the template

From the repository root, set `platform` to `gcp` or `aws` and choose a new
project directory name. The same procedure works for the other platforms.
Copy configuration explicitly and recreate the shared symlinks so a working
template directory's local credentials, state, or cache are never copied.

```bash
platform=gcp
project=my-project

rtk proxy mkdir "$platform/envs/$project"
rtk proxy cp "$platform/envs/example/main.tf" "$platform/envs/$project/main.tf"
rtk proxy ln -s ../../_shared/variables.tf "$platform/envs/$project/variables.tf"
rtk proxy ln -s ../../_shared/outputs.tf "$platform/envs/$project/outputs.tf"
rtk proxy cp "$platform/envs/example/terraform.tfvars.example" "$platform/envs/$project/terraform.tfvars"
if [ "$platform" != "proxmox" ]; then
  rtk proxy cp "$platform/envs/example/backend.hcl.example" "$platform/envs/$project/backend.hcl"
fi
if [ -f "$platform/envs/example/.terraform.lock.hcl" ]; then
  rtk proxy cp "$platform/envs/example/.terraform.lock.hcl" "$platform/envs/$project/.terraform.lock.hcl"
fi
```

For an existing project, follow the [restore workflow](#local-projects-and-manual-backups)
instead of generating new input/backend files.

### Configure inputs, backend, and authentication

Edit the new project's `terraform.tfvars` and remove unneeded sample resources.
Set its identity, locations, and resource lists. Configure the matching backend
in its `backend.hcl`; the state bucket must already exist. New projects need a
unique state prefix/key, such as `gcp/my-project` for GCS or
`aws/my-project/terraform.tfstate` for AWS/R2.

**GCP:** Set `project_id`, `env`, `region`, and `zone`. The directory name is
independent of `env`, which has no validation restrictions. The template uses
GCS. For S3/R2, change the new project's `main.tf` to `backend "s3" {}`, remove
the GCS attributes from `backend.hcl`, and use only the template's S3 section
with `key = "gcp/my-project/terraform.tfstate"`. Both Google providers are
already configured. For ADC authentication:

```bash
rtk proxy gcloud auth application-default login
```

**AWS:** Set `region`, `env`, and provider authentication, such as
`aws_profile = "your-profile"`. The backend template targets R2; fill its bucket,
key, endpoint, and R2 credentials. For native S3, use the AWS region and backend
authentication, removing R2-specific endpoint and skip settings. Keep AWS
provider authentication separate from R2 backend credentials. For SSO:

```bash
rtk proxy aws sso login --profile your-profile
```

The current AWS example forwards only `vpcs` to the root module. To manage
IAM, EC2, RDS, Lambda, or budgets, add the corresponding input forwarding to
the new project's `module "aws"` block; setting those values in tfvars alone
does not enable them. `aws/envs/logic3579/main.tf` shows the broader wiring,
but also omits `iam_users`. Preserve any custom entrypoint with your backups.

**Proxmox:** Set endpoint/authentication and resource inputs. It uses local
state and has no `backend.hcl`.

**OpenStack:** Set Keystone authentication and resource inputs. Configure the
S3 backend for Swift and export its EC2 credentials as `AWS_ACCESS_KEY_ID`
and `AWS_SECRET_ACCESS_KEY` before init.

**Vultr:** Export `VULTR_API_KEY` in the Terraform shell and leave `api_key`
unset in tfvars. Configure R2 credentials separately in `backend.hcl`.

### Initialize and review the new project

Continue from the repository root with the same `platform` and `project`
variables. For GCP, AWS, OpenStack, and Vultr:

```bash
rtk proxy terraform -chdir="$platform/envs/$project" init -backend-config=backend.hcl
rtk proxy terraform -chdir="$platform/envs/$project" validate
rtk proxy terraform -chdir="$platform/envs/$project" plan
```

For Proxmox, omit `-backend-config=backend.hcl` from init. Review the plan before
applying it:

```bash
rtk proxy terraform -chdir="$platform/envs/$project" apply
```

Back up the project configuration after setup and whenever it changes.

## Local projects and manual backups

Back up `terraform.tfvars` and `backend.hcl` outside Git, either manually or
with separate [sync commands](#sync-project-configuration). On another machine,
recreate only the project entrypoint and symlinks first. Do not generate fresh
input/backend values for an existing project. For example, from the repository
root, after setting `platform` and `project` to the original names:

```bash
rtk proxy mkdir "$platform/envs/$project"
rtk proxy cp "$platform/envs/example/main.tf" "$platform/envs/$project/main.tf"
rtk proxy ln -s ../../_shared/variables.tf "$platform/envs/$project/variables.tf"
rtk proxy ln -s ../../_shared/outputs.tf "$platform/envs/$project/outputs.tf"
```

Restore both files manually, or download them using the same storage, bucket,
and project names as the backups. For R2, authenticate with `cf` first; the
sync storage credentials must be available before restoring backend credentials:

```bash
rtk proxy cf auth login
rtk proxy ./scripts/tfvars-sync.sh download --platform "$platform" --env "$project" --storage r2 --file terraform.tfvars
rtk proxy ./scripts/tfvars-sync.sh download --platform "$platform" --env "$project" --storage r2 --file backend.hcl
```

Pass `--bucket` if the backups use a non-default bucket. Restore provider
authentication separately, then run init, validate, and plan as above.
Keep the original backend type, bucket, and prefix/key to manage the same state.

Use an entrypoint matching the restored backend: GCP `example` uses GCS, while
GCP `logic3579` uses S3/R2. Restore custom `main.tf` wiring when applicable.
Proxmox uses local state, has no `backend.hcl`, and needs
`terraform.tfstate` backed up and restored separately before `terraform init`.
Preserve customized entrypoints, additional assets, and local provider lockfiles
alongside the two configuration files when needed to reproduce a project.

Ignored project files stay on disk; Git does not back them up.

## Sync project configuration

Run `scripts/tfvars-sync.sh` from the repository root to upload or download one
configuration file at a time. Use `--file terraform.tfvars` (the default, so
existing commands still work) or `--file backend.hcl`. Objects use
`<platform>/<env>/<file>`; the default bucket is `terraform-state`.
Omit `--env` to process every local project for that platform, including
Git-ignored directories; specify `--env` to select one. Back up and restore both
files for projects with remote state before managing them on another machine.

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

# Back up and restore backend.hcl for the same project separately.
rtk proxy ./scripts/tfvars-sync.sh upload --platform vultr --env logic3579 --storage r2 --file backend.hcl
rtk proxy ./scripts/tfvars-sync.sh download --platform vultr --env logic3579 --storage r2 --file backend.hcl

# Sync all GCP environments to a selected GCS bucket.
rtk proxy ./scripts/tfvars-sync.sh upload --platform gcp --storage gcs --bucket my-tfvars-bucket
```

Downloads replace the selected local file only after a successful transfer
through a temporary file; preserve local edits first. Failed downloads leave
the existing configuration intact. Uploads skip missing selected files.
The script does not sync Terraform state, and the sync bucket is independent
of the backend being backed up. Restore credentials needed to access the sync
bucket separately; a stored `backend.hcl` is a backup, not backend initialization.

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
- `*.tfvars` and `*.tfstate` are gitignored — use `<platform>/envs/example/terraform.tfvars.example` as the template.
- `.cloudflare/` is local CLI cache and is also gitignored. Keep provider lockfiles tracked for `example` and `logic3579`; preserve local projects' lockfiles with their backups.
- Be mindful of cloud costs.
- See [AGENTS.md](AGENTS.md) for project conventions and module architecture.
