# OpenStack Terraform

Manages OpenStack infrastructure via the [`terraform-provider-openstack/openstack`](https://registry.terraform.io/providers/terraform-provider-openstack/openstack) provider.

## Layout

```
openstack/
├── _shared/              # variable / output decls (symlinked from each env)
├── envs/devtest/         # devtest env: provider + backend + module call
├── modules/
│   ├── network/          # networks, subnets, routers, secgroups, floating IPs
│   ├── compute/          # instances + keypairs
│   └── storage/          # Cinder block volumes
├── main.tf               # root module — wires submodules
├── variables.tf          # root input type definitions
├── outputs.tf            # root output forwarders
└── versions.tf           # provider version pin
```

## Usage

```bash
cd openstack/envs/devtest
cp ../terraform.tfvars.example terraform.tfvars   # then edit values

# state backend uses Swift's S3-compatible API; export EC2 creds first
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...

terraform init -backend-config=backend.hcl
terraform plan
terraform apply
```

## Authentication

Pass Keystone v3 credentials via `terraform.tfvars` (or use `OS_*` env vars and
strip the corresponding `provider` block fields).

```hcl
auth_url    = "https://keystone.example.com:5000/v3"
user_name   = "admin"
password    = "..."
tenant_name = "admin"
```

## State backend

Terraform's native `swift` backend was removed in 1.3, so we use the `s3`
backend pointed at Swift's S3-compatible endpoint. Generate EC2 credentials:

```bash
openstack ec2 credentials create
```

then set `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` and edit
`envs/<env>/backend.hcl` with your Swift endpoint.

## Extending

The current module set is intentionally minimal. Common additions:

| Need                 | Resource                                                          |
|----------------------|--------------------------------------------------------------------|
| Octavia load balancer| `openstack_lb_loadbalancer_v2` / `_listener_v2` / `_pool_v2`       |
| Designate DNS        | `openstack_dns_zone_v2` / `_recordset_v2`                          |
| Glance image upload  | `openstack_images_image_v2` (resource, not data)                   |
| Identity (Keystone)  | `openstack_identity_project_v3` / `_user_v3` / `_role_assignment_v3` |
| Object storage       | `openstack_objectstorage_container_v1`                             |
| Server groups        | `openstack_compute_servergroup_v2` (affinity / anti-affinity)      |
| Volume attach        | `openstack_compute_volume_attach_v2`                               |
| FIP association      | `openstack_compute_floatingip_associate_v2`                        |
