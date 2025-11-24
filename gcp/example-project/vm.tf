# GCP VM Instance Configuration

# 获取项目信息
data "google_project" "current" {
  project_id = var.project_id
}

# 获取默认服务账户
data "google_compute_default_service_account" "default" {
  project = var.project_id
}

# 为每个实例创建静态外部 IP 地址
resource "google_compute_address" "vm_external_ip" {
  for_each = merge([
    for vm_key, config in var.vm_instances : {
      for instance in config.instances :
      vm_key => {
        name   = instance.name
        region = instance.region
      }
    }
  ]...)

  name   = "${each.value.name}-external-ip"
  region = each.value.region
}

# 为每个实例创建 VM
resource "google_compute_instance" "vm_instance" {
  for_each = merge([
    for vm_key, config in var.vm_instances : {
      for instance in config.instances :
      vm_key => {
        name          = instance.name
        machine_type  = instance.machine_type
        zone          = instance.zone
        region        = instance.region
        image_family  = instance.image_family
        image_project = instance.image_project
        disk_size     = instance.disk_size
        disk_type     = instance.disk_type
        network_tags  = instance.network_tags
        network       = instance.network
        subnetwork    = instance.subnetwork
      }
    }
  ]...)
  name         = each.value.name
  machine_type = each.value.machine_type
  zone         = each.value.zone
  tags         = each.value.network_tags

  allow_stopping_for_update = true

  boot_disk {
    initialize_params {
      image = "${each.value.image_project}/${each.value.image_family}"
      size  = each.value.disk_size
      type  = each.value.disk_type
    }
  }

  network_interface {
    network    = "projects/${var.project_id}/global/networks/${each.value.network}"
    subnetwork = "projects/${var.project_id}/regions/${each.value.region}/subnetworks/${each.value.subnetwork}"

    access_config {
      nat_ip = google_compute_address.vm_external_ip[each.key].address
    }
  }

  # 启动脚本 - 安装 Docker
  # 注意：metadata 变更已在 lifecycle 中设置为 ignore_changes，不会导致实例重建
  metadata_startup_script = <<-EOF
    #!/bin/bash
    
    # 更新系统包
    apt-get update
    apt-get install -y ca-certificates curl gnupg lsb-release
    
    # 添加 Docker 官方 GPG 密钥
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    # 添加 Docker 仓库
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # 更新包索引并安装指定版本 Docker
    apt update
    VERSION_STRING="5:28.5.2-1~ubuntu.22.04~jammy"
    apt install docker-ce=$VERSION_STRING docker-ce-cli=$VERSION_STRING containerd.io docker-buildx-plugin docker-compose-plugin
    
    # 启动并启用 Docker 服务
    systemctl start docker
    systemctl enable docker
    
    # 验证 Docker 安装
    docker --version
    docker compose version
  EOF

  # 服务账户设置 - 使用默认 Compute Engine 服务账户
  service_account {
    email  = data.google_compute_default_service_account.default.email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  # 实例调度配置
  scheduling {
    preemptible       = false
    automatic_restart = true
  }

  # 生命周期配置
  lifecycle {
    prevent_destroy = false
    # 忽略 metadata 变更，避免因启动脚本变化导致实例重建
    ignore_changes = [
      metadata,
      metadata_startup_script,
    ]
  }
}

# 输出信息 - VM 实例详情
output "vm_instance_info" {
  value = {
    for key, instance in google_compute_instance.vm_instance : key => {
      name         = instance.name
      machine_type = instance.machine_type
      zone         = instance.zone
      internal_ip  = instance.network_interface[0].network_ip
      external_ip  = instance.network_interface[0].access_config[0].nat_ip
      network_tags = instance.tags
      network      = split("/", instance.network_interface[0].network)[length(split("/", instance.network_interface[0].network)) - 1]
      subnetwork   = split("/", instance.network_interface[0].subnetwork)[length(split("/", instance.network_interface[0].subnetwork)) - 1]
      static_ip    = google_compute_address.vm_external_ip[key].address
    }
  }
  description = "Detailed information about all VM instances"
}

# 输出信息 - 外部 IP 地址信息
output "external_ip_info" {
  value = {
    for key, ip in google_compute_address.vm_external_ip : key => {
      static_ip_name    = ip.name
      static_ip_address = ip.address
      region            = ip.region
      vm_external_ip    = google_compute_instance.vm_instance[key].network_interface[0].access_config[0].nat_ip
    }
  }
  description = "External IP address information for all instances"
}

# 输出信息 - 连接信息
output "connection_info" {
  value = {
    for key, instance in google_compute_instance.vm_instance : key => {
      ssh_command  = "gcloud compute ssh ${instance.name} --zone=${instance.zone} --project=${var.project_id}"
      ssh_external = "ssh -i ~/.ssh/id_rsa username@${instance.network_interface[0].access_config[0].nat_ip}"
      internal_ip  = instance.network_interface[0].network_ip
      external_ip  = instance.network_interface[0].access_config[0].nat_ip
    }
  }
  description = "Information for connecting to all VM instances"
}
