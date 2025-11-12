# GCP Terraform 项目管理

本目录包含多个 GCP 项目的 Terraform 配置，每个子目录代表一个独立的 GCP 项目环境。

## 目录结构

```
gcp/
├── README.md                      # 本文件
├── example-project/               # GCP 项目配置
│   ├── instance_group.tf          # Instance Group 配置
│   ├── load_balancer.tf           # Load Balancer 配置
│   ├── provider.tf                # Provider 配置
│   ├── service_account.tf         # IAM Service Account 配置
│   ├── storage.tf                 # GCS Bucket 配置
│   ├── variables.tf               # 变量定义
│   ├── vpc.tf                     # VPC 和防火墙规则
│   ├── vm.tf                      # VM 实例配置
│   ├── nat.tf                     # Cloud NAT 配置
│   ├── keys/                      # Service Account Keys 目录（gitignored）
│   ├── terraform.tfvars           # 实际变量值（gitignored）
│   └── terraform.tfvars.example   # 变量示例文件
└── [其他项目目录]/                # 其他 GCP 项目
```

## 前置要求

### 1. 安装 Terraform

```bash
# macOS
brew install terraform

# 验证安装
terraform version
```

### 2. 配置 GCP 认证

**方式 1：使用 gcloud CLI（推荐）**

```bash
# 安装 gcloud CLI
brew install --cask google-cloud-sdk

# 登录 Google 账号
gcloud auth login

# 设置应用默认凭证
gcloud auth application-default login

# 设置默认项目
gcloud config set project YOUR_PROJECT_ID
```

**方式 2：使用服务账号密钥**

```bash
# 下载服务账号密钥文件到安全位置
# 例如：~/.gcp/your-project-key.json

# 设置环境变量
export GOOGLE_CREDENTIALS="~/.gcp/your-project-key.json"
```

## 快速开始

### 1. 选择项目目录

```bash
cd gcp/example-project  # 或其他项目目录
```

### 2. 配置变量

```bash
# 复制示例文件
cp terraform.tfvars.example terraform.tfvars

# 编辑配置文件
vim terraform.tfvars
```

**重要配置项说明：**

#### subnet_configs（子网配置）
```hcl
subnet_configs = {
  "subnet-name" = {
    region             = "region-name"
    primary_ipv4_range = "CIDR-range"
  }
}
```

#### vm_instances（VM 实例配置）
```hcl
vm_instances = {
  "vm-instance-key" = {  # 使用 VM 名称作为 key
    instances = [
      {
        name          = "vm-name"
        machine_type  = "machine-type"
        region        = "region-name"  # 必须指定 region
        zone          = "zone-name"
        image_family  = "ubuntu-2204-lts"
        image_project = "ubuntu-os-cloud"
        disk_size     = 100
        disk_type     = "pd-balanced"
        network_tags  = ["tag1", "tag2"]
        network       = "vpc-network-name"
        subnetwork    = "subnet-name"  # 必须在 subnet_configs 中定义
      }
    ]
  }
}
```

### 3. 初始化 Terraform

```bash
# 初始化工作目录，下载 provider 插件
terraform init
```

### 4. 验证配置

```bash
# 验证配置语法
terraform validate

# 格式化代码
terraform fmt
```

### 5. 查看执行计划

```bash
# 查看将要创建/修改/删除的资源
terraform plan

# 保存执行计划到文件
terraform plan -out=tfplan
```

### 6. 应用配置

```bash
# 交互式应用（需要确认）
terraform apply

# 自动批准应用
terraform apply -auto-approve

# 使用保存的计划文件
terraform apply tfplan
```

### 7. 查看输出

```bash
# 查看所有输出
terraform output

# 查看特定输出
terraform output vm_instance_info
terraform output connection_info
```

## 导入现有资源

如果 GCP 中已经存在某些资源，需要将它们导入到 Terraform 状态中，避免冲突。

### 导入防火墙规则

```bash
terraform import google_compute_firewall.RESOURCE_NAME projects/PROJECT_ID/global/firewalls/FIREWALL_NAME
```

**示例：**
```bash
terraform import google_compute_firewall.example_project_allow_ssh projects/example-project/global/firewalls/example-project-allow-ssh
```

### 导入 VM 实例

```bash
terraform import google_compute_instance.vm_instance["VM_INSTANCE_KEY"] projects/PROJECT_ID/zones/ZONE/instances/INSTANCE_NAME
```

**示例：**
```bash
# VM instance key 对应 vm_instances 中的 key（VM 名称）
terraform import google_compute_instance.vm_instance["algorithm-ew1-vm1"] projects/example-project/zones/europe-west1-b/instances/algorithm-ew1-vm1
```

### 导入静态 IP 地址

```bash
terraform import google_compute_address.vm_external_ip["VM_INSTANCE_KEY"] projects/PROJECT_ID/regions/REGION/addresses/ADDRESS_NAME
```

**示例：**
```bash
# VM instance key 对应 vm_instances 中的 key（VM 名称）
terraform import google_compute_address.vm_external_ip["algorithm-ew1-vm1"] projects/example-project/regions/europe-west1/addresses/algorithm-ew1-vm1-external-ip
```

### 导入 VPC 网络

```bash
terraform import google_compute_network.RESOURCE_NAME projects/PROJECT_ID/global/networks/NETWORK_NAME
```

### 导入子网

```bash
terraform import google_compute_subnetwork.RESOURCE_NAME["KEY"] projects/PROJECT_ID/regions/REGION/subnetworks/SUBNET_NAME
```

## 常用操作

### 查看当前状态

```bash
# 列出所有资源
terraform state list

# 查看特定资源详情
terraform state show 'google_compute_instance.vm_instance["algorithm-ew2-vm1"]'
terraform state show 'google_compute_address.vm_external_ip["algorithm-ew2-vm1-external-ip"]'
```

### 刷新状态

```bash
# 从 GCP 刷新状态
terraform refresh
```

### 销毁资源

```bash
# 销毁所有资源（需要确认）
terraform destroy

# 自动批准销毁
terraform destroy -auto-approve

# 销毁特定资源
terraform destroy -target=google_compute_instance.vm_instance[\"europe-west1-0\"]
```

### 移除资源（不删除实际资源）

```bash
# 从 Terraform 状态中移除，但不删除 GCP 中的资源
terraform state rm google_compute_address.vm_external_ip['algorithm-ew1-vm1']
terraform state rm google_compute_instance.vm_instance['algorithm-ew1-vm1']
```

## 变量配置详解

### 项目基础配置

```hcl
project_id       = "your-project-id"        # GCP 项目 ID
project_name     = "your-project-name"      # 项目名称
default_region   = "asia-southeast1"        # 默认区域
default_zone     = "asia-southeast1-a"      # 默认可用区
current_vpc_name = "your-vpc-name"          # VPC 网络名称
```

### VM 实例配置说明

**重要变更：** VM 实例的 key 现在使用 VM 名称而不是 region。

```hcl
vm_instances = {
  "algorithm-ew2-vm1" = {  # Key 使用 VM 名称
    instances = [
      {
        name          = "algorithm-ew2-vm1"
        machine_type  = "custom-8-16384"
        region        = "europe-west2"     # 必须指定 region
        zone          = "europe-west2-a"
        image_family  = "ubuntu-2204-lts"
        image_project = "ubuntu-os-cloud"
        disk_size     = 20
        disk_type     = "pd-balanced"
        network_tags  = ["algorithm"]
        network       = "your-vpc-name"
        subnetwork    = "algorithm-ew2"
      }
    ]
  }
}
```

**关键点：**
- `vm_instances` 的 key 使用 VM 实例名称（如 `"algorithm-ew2-vm1"`）
- 每个实例配置中必须包含 `region` 字段
- Instance Group 的 `instances` 列表引用这些 key

### Instance Group 配置说明

```hcl
instance_groups = {
  "algorithm-ew2-a" = {  # Instance Group 的标识符
    name        = "algorithm-ew2-a-ig"
    description = "Instance group for algorithm VMs"
    zone        = "europe-west2-a"
    instances   = ["algorithm-ew2-vm1"]  # 引用 vm_instances 的 key
    named_ports = [
      {
        name = "http"
        port = 8080
      },
      {
        name = "revo-ai"
        port = 8000
      }
    ]
  }
}
```

**关键点：**
- `instances` 列表中的值必须对应 `vm_instances` 中的 key
- 可以将多个 VM 实例添加到同一个 Instance Group
- 命名端口用于负载均衡器配置

### Load Balancer 配置说明

**配置类型：** Global External Application Load Balancer

```hcl
# Load Balancer 基础配置
lb_name                  = "ortb-lb"
lb_external_ip_name      = "ortb-lb-external-ip"
lb_forwarding_rule_name  = "ortb-lb-forwarding-rule"
lb_backend_service_name  = "ortb-global-backend"
lb_health_check_name     = "ortb-health-check"

# Backend 配置
lb_backends = {
  "backend-ew2-a" = {
    instance_group_key = "algorithm-ew2-a"  # 对应 instance_groups 的 key
    balancing_mode     = "UTILIZATION"
    capacity_scaler    = 1.0
    max_utilization    = 0.8
  }
}
```

**关键特性：**
- ✅ Global 区域访问
- ✅ External 外部访问
- ✅ HTTP 协议（端口 80 和 8000）
- ✅ 静态外部 IP
- ✅ 多端口支持（同一 IP，不同端口）
- ✅ TCP Health Check（端口 8080 和 8000）
- ✅ Session Affinity（Client IP）
- ✅ 支持多个 Backend Instance Groups

**配置文档：**
- [LOAD_BALANCER_GUIDE.md](example-project/LOAD_BALANCER_GUIDE.md) - 基础配置指南
- [MULTI_PORT_LB_GUIDE.md](example-project/MULTI_PORT_LB_GUIDE.md) - 多端口配置指南

**多端口配置：**

本项目配置了两个端口的 Load Balancer：

| 端口 | 服务 | Backend Port | Named Port | 用途 |
|------|------|--------------|------------|------|
| 80 | HTTP | 8080 | http | 主服务 |
| 8000 | HTTP | 8000 | revo-ai | AI 服务 |

访问方式：
```bash
# 主服务（8080）
curl http://LB_IP:80

# AI 服务（8000）
curl http://LB_IP:8000
```

### GCS Bucket 和 IAM Service Account 配置说明

**配置类型：** Cloud Storage Bucket + IAM Service Account

```hcl
# GCS Bucket 配置
gcs_buckets = {
  "adwave-uat" = {
    name               = "adwave-uat"
    location           = "asia-southeast1"  # Region
    storage_class      = "STANDARD"
    versioning_enabled = false
  }
}

# IAM Service Account 配置
service_accounts = {
  "applications-dev" = {
    account_id       = "applications-dev"
    display_name     = "Applications Development Service Account"
    roles = [
      "roles/firebasestorage.serviceAgent"  # Cloud Storage for Firebase Service Agent
    ]
    create_key       = true   # 创建 Service Account Key
    save_key_to_file = true   # 保存 Key 到文件
  }
}
```

**GCS Bucket 特性：**
- ✅ Region 存储（单可用区）
- ✅ Standard 存储类
- ✅ Public Access Prevention: On
- ✅ Uniform Access Control
- ✅ Soft Delete Policy (7 days)
- ✅ Google-managed Encryption

**Service Account 特性：**
- ✅ 自动创建 Service Account
- ✅ 分配 IAM 角色
- ✅ 生成 Service Account Key (JSON)
- ✅ 保存 Key 到本地文件 (`keys/` 目录)
- ✅ 输出 Key 内容（Base64 和 JSON 格式）

**Service Account Key 位置：**
```
example-project/keys/applications-dev-key.json
```

**使用 Service Account Key：**
```bash
# 设置环境变量
export GOOGLE_APPLICATION_CREDENTIALS="keys/applications-dev-key.json"

# 测试访问 Bucket
gsutil ls gs://adwave-uat/
```

**配置文档：** [STORAGE_AND_IAM_GUIDE.md](example-project/STORAGE_AND_IAM_GUIDE.md)

### 常用 GCP 区域和可用区

| 区域 | 可用区 | 位置 |
|------|--------|------|
| `asia-southeast1` | a, b, c | 新加坡 |
| `asia-east1` | a, b, c | 台湾 |
| `asia-northeast1` | a, b, c | 东京 |
| `europe-west1` | b, c, d | 比利时 |
| `europe-west2` | a, b, c | 伦敦 |
| `us-central1` | a, b, c, f | 爱荷华 |
| `us-west1` | a, b, c | 俄勒冈 |
| `us-east1` | b, c, d | 南卡罗来纳 |

### 机器类型参考

| 类型 | 规格 | 说明 |
|------|------|------|
| `e2-micro` | 0.25-2 vCPU, 1GB RAM | 最小实例 |
| `e2-small` | 0.5-2 vCPU, 2GB RAM | 小型实例 |
| `e2-medium` | 1-2 vCPU, 4GB RAM | 中型实例 |
| `e2-standard-2` | 2 vCPU, 8GB RAM | 标准实例 |
| `e2-standard-4` | 4 vCPU, 16GB RAM | 标准实例 |
| `custom-8-16384` | 8 vCPU, 16GB RAM | 自定义实例 |
| `custom-16-32768` | 16 vCPU, 32GB RAM | 自定义实例 |

### 磁盘类型

| 类型 | 说明 | 性能 |
|------|------|------|
| `pd-standard` | 标准持久化磁盘 | 低成本，低性能 |
| `pd-balanced` | 平衡持久化磁盘 | 平衡性能和成本 |
| `pd-ssd` | SSD 持久化磁盘 | 高性能，高成本 |

## 故障排查

### 常见错误

#### 1. 认证错误

**错误信息：**
```
Error: Attempted to load application default credentials
```

**解决方案：**
```bash
gcloud auth application-default login
```

#### 2. Zone 不存在

**错误信息：**
```
Error: Error loading zone 'europe-west1-a': Unknown zone
```

**解决方案：**
检查并使用正确的可用区。例如 `europe-west1` 只有 `b`, `c`, `d`，没有 `a`。

#### 3. 资源已存在

**错误信息：**
```
Error: The resource already exists
```

**解决方案：**
使用 `terraform import` 导入现有资源。

#### 4. Provider 插件缺失或损坏

**错误信息：**
```
Error: missing or corrupted provider plugins
- registry.terraform.io/hashicorp/google: there is no package ...
- registry.terraform.io/hashicorp/local: there is no package ...
```

**原因：**
- 首次执行 `terraform plan/apply` 前未运行 `terraform init`
- `.terraform/` 目录被清理/损坏，导致缓存的 Provider 插件缺失
- Provider 版本在 lock 文件中更新，但本地插件缓存未同步

**解决步骤：**
```bash
# 1. 进入项目目录
cd gcp/example-project

# 2. 可选：清理旧的 Provider 缓存
rm -rf .terraform

# 3. 重新初始化，下载所需 Provider 插件
terraform init -upgrade

# 4. 验证
terraform providers
```

**说明：**
- `terraform init` 会根据 `.terraform.lock.hcl` 中锁定的版本下载并校验插件
- 使用 `-upgrade` 可以在需要时更新已有插件缓存，确保与锁定版本一致
- 如使用远程执行环境（CI/CD），必须在每次执行前运行 `terraform init`

#### 5. 实例需要重建（metadata_startup_script 变更）

**错误信息：**
```
# google_compute_instance.vm_instance["vm-name"] must be replaced
+/- resource "google_compute_instance" "vm_instance" {
    + metadata_startup_script = ... # forces replacement
```

**原因：**
- 现有实例使用 `metadata["startup-script"]`
- 新配置使用 `metadata_startup_script`
- Terraform 认为这是不同的配置方式

**解决方案：**

已在 `vm.tf` 中添加 `lifecycle.ignore_changes` 配置：

```hcl
lifecycle {
  prevent_destroy = false
  ignore_changes = [
    metadata,
    metadata_startup_script,
  ]
}
```

这样可以：
- ✅ 避免因 metadata 变更导致实例重建
- ✅ 保护已运行的实例不受启动脚本变更影响
- ✅ 新实例仍会应用启动脚本

#### 6. Load Balancer Health Check 失败

**错误信息：**
```
Backend instances are unhealthy
```

**原因：**
Health Check 无法访问实例的 8080 端口

**解决方案：**

添加防火墙规则允许 Health Check 探测：

```hcl
firewall_rules = {
  "allow-health-check" = {
    name          = "your-project-allow-health-check"
    description   = "Allow health check probes from GCP"
    priority      = 1000
    source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]  # GCP Health Check IP 范围
    target_tags   = ["algorithm"]
    allow = [
      {
        protocol = "tcp"
        ports    = ["8080"]
      }
    ]
  }
}
```

**验证：**
```bash
# 检查 Health Check 状态
gcloud compute backend-services get-health ortb-global-backend --global
```

#### 7. Load Balancer Consistent Hash 配置错误

**错误信息：**
```
Error: ConsistentHash can be set only if the Locality Lb policy is set to MAGLEV or RING_HASH.
```

**原因：**
使用 `consistent_hash` 必须同时设置 `locality_lb_policy`

**解决方案：**

已在 `load_balancer.tf` 中添加：

```hcl
resource "google_compute_backend_service" "global_backend" {
  session_affinity   = "CLIENT_IP"
  locality_lb_policy = "RING_HASH"  # 必须设置
  
  consistent_hash {
    minimum_ring_size = 1024
  }
}
```

#### 8. Forwarding Rule IP 配置冲突

**错误信息：**
```
Error: IP Version and IP Address cannot be specified at the same time.
```

**原因：**
在 Forwarding Rule 中不能同时指定 `ip_version` 和 `ip_address`

**解决方案：**

移除 `ip_version`，IP 版本会自动从地址推断：

```hcl
resource "google_compute_global_forwarding_rule" "lb_forwarding_rule" {
  ip_address = google_compute_global_address.lb_external_ip.address
  # 移除 ip_version = "IPV4"  # 会自动推断
}
```

#### 9. 权限不足

**错误信息：**
```
Error: Permission denied
```

**解决方案：**
确保你的账号或服务账号具有以下权限：
- Compute Admin
- Service Account User
- Network Admin

### 查看日志

```bash
# 启用详细日志
export TF_LOG=DEBUG
terraform apply

# 保存日志到文件
export TF_LOG_PATH=./terraform.log
terraform apply
```

## 最佳实践

### 1. 使用版本控制

```bash
# 初始化 git 仓库
git init

# 确保 .gitignore 包含敏感文件
echo "terraform.tfvars" >> .gitignore
echo "*.tfstate*" >> .gitignore
echo ".terraform/" >> .gitignore
```

### 2. 使用 Terraform Backend

在 `provider.tf` 中配置远程状态存储：

```hcl
terraform {
  backend "gcs" {
    bucket = "your-terraform-state-bucket"
    prefix = "terraform/state"
  }
}
```

### 3. 使用工作空间

```bash
# 创建新工作空间
terraform workspace new dev
terraform workspace new prod

# 切换工作空间
terraform workspace select dev

# 查看当前工作空间
terraform workspace show

# 列出所有工作空间
terraform workspace list
```

### 4. 使用变量文件

```bash
# 使用不同环境的变量文件
terraform apply -var-file="dev.tfvars"
terraform apply -var-file="prod.tfvars"
```

### 5. 定期备份状态文件

```bash
# 备份状态文件
terraform state pull > terraform.tfstate.backup.$(date +%Y%m%d)
```

## 安全建议

1. **不要提交敏感信息**
   - `terraform.tfvars` 应该在 `.gitignore` 中
   - 服务账号密钥文件不要提交到版本控制

2. **使用最小权限原则**
   - 为服务账号分配最小必要权限
   - 定期审查和轮换密钥

3. **启用防火墙规则**
   - 限制 SSH 访问的源 IP 范围
   - 使用网络标签管理访问控制

4. **使用私有 IP**
   - 考虑使用 Cloud NAT 而不是公网 IP
   - 通过 VPN 或 Cloud IAP 访问实例

5. **定期更新**
   - 定期更新 Terraform 版本
   - 定期更新 Provider 版本

## 资源链接

- [Terraform 官方文档](https://www.terraform.io/docs)
- [Google Provider 文档](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [GCP 区域和可用区](https://cloud.google.com/compute/docs/regions-zones)
- [GCP 机器类型](https://cloud.google.com/compute/docs/machine-types)
- [GCP 定价计算器](https://cloud.google.com/products/calculator)

## 支持

如有问题或建议，请联系基础设施团队。
