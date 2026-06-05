# Proxmox VE Terraform

Manages Proxmox VE infrastructure via the [`bpg/proxmox`](https://registry.terraform.io/providers/bpg/proxmox) provider.

## Layout

```
proxmox/
├── _shared/              # variable / output decls (symlinked from each env)
├── envs/dev/            # dev env: provider + backend + module call (copy to test/prod as needed)
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

```bash
cd proxmox/envs/dev
cp ../terraform.tfvars.example terraform.tfvars   # then edit values

terraform init
terraform plan
terraform apply
```

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
