# Proxmox VE Terraform

Manages Proxmox VE infrastructure via the [`bpg/proxmox`](https://registry.terraform.io/providers/bpg/proxmox) provider.

## Layout

```
proxmox/
├── _shared/              # variable / output decls (symlinked from each env)
├── envs/example/         # complete example project
│   ├── main.tf
│   ├── variables.tf      # → ../../_shared/variables.tf
│   ├── outputs.tf        # → ../../_shared/outputs.tf
│   └── terraform.tfvars.example
├── modules/
│   ├── network/          # Linux bridges (vmbrN)
│   ├── storage/          # ISOs / cloud images / LXC templates downloaded to PVE
│   └── compute/          # KVM VMs (with optional cloud-init)
├── main.tf               # root module — wires submodules
├── variables.tf          # root input type definitions
├── outputs.tf            # root output forwarders
└── versions.tf           # provider version pin
```

## Usage

Only `example` and `logic3579` project directories may be tracked; currently
this platform includes `example`. Create other projects locally from
`example/main.tf` and recreate the shared symlinks. Their directories are
gitignored. Manually back up `terraform.tfvars` and local state outside Git;
restore both before managing the project on another machine. This platform
does not use `backend.hcl`. See the
[backup workflow](../README.md#local-projects-and-manual-backups).

```bash
project=my-project
rtk proxy mkdir "proxmox/envs/$project"
rtk proxy cp proxmox/envs/example/main.tf "proxmox/envs/$project/main.tf"
rtk proxy ln -s ../../_shared/variables.tf "proxmox/envs/$project/variables.tf"
rtk proxy ln -s ../../_shared/outputs.tf "proxmox/envs/$project/outputs.tf"
rtk proxy cp proxmox/envs/example/terraform.tfvars.example "proxmox/envs/$project/terraform.tfvars"
```

Edit the new project's inputs before initialization. From the repository root:

```bash
rtk proxy terraform -chdir="proxmox/envs/$project" init
rtk proxy terraform -chdir="proxmox/envs/$project" validate
rtk proxy terraform -chdir="proxmox/envs/$project" plan
```

Review the plan before `rtk proxy terraform -chdir="proxmox/envs/$project" apply`.
Keep `example` as the source template. See the root
[Git ignore rules](../README.md#git-ignore-rules) for project tracking.

## Authentication

Pass an API token (preferred) or username/password via `terraform.tfvars`:

```hcl
endpoint  = "https://pve.example.com:8006/"
api_token = "terraform@pve!tfci=00000000-..."
```

Create the token at **Datacenter → Permissions → API Tokens**, then grant it the
needed roles via **Datacenter → Permissions → Add → API Token Permission**.

## Provider version pin

`bpg/proxmox` is pinned to `~> 0.104.0`. v0.105 introduced a Plugin Framework
rewrite of the network resources that has a schema bug on the `ports` attribute,
breaking `terraform validate`. Bump once the upstream fix lands.

## State backend

Local file (`terraform.tfstate` in the env dir). Proxmox has no native Terraform
backend — common alternatives for team use are an S3-compatible store like
[MinIO](https://min.io/) or the HTTP backend backed by GitLab/Gitea.
Backing up only `terraform.tfvars` does not preserve the managed resource state.

## Extending

The current module set is intentionally minimal. Common additions:

| Need                        | Resource                                              |
|-----------------------------|--------------------------------------------------------|
| LXC containers              | `proxmox_virtual_environment_container`               |
| Users / groups / ACLs       | `proxmox_virtual_environment_user`/`_group`/`_acl`    |
| HA groups                   | `proxmox_virtual_environment_hagroup`/`_haresource`   |
| Datacenter / VM firewall    | `proxmox_virtual_environment_firewall_rules`          |
| Resource pools              | `proxmox_virtual_environment_pool`                    |
| Cloud-init userdata snippet | `proxmox_virtual_environment_file` (requires SSH)     |
