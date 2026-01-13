#cloud-config

# Hostname Configuration
%{ if hostname != "" ~}
hostname: ${hostname}
prefer_fqdn_over_hostname: false
%{ endif ~}

# Package Management
package_update: true
package_upgrade: false
package_reboot_if_required: false

# Install basic utilities first
packages:
  - ca-certificates
  - curl
%{ for package in packages ~}
  - ${package}
%{ endfor ~}

# Timezone Configuration
timezone: UTC

# System Configuration
preserve_hostname: false

%{ if install_docker ~}
# Install Docker from official repository
runcmd:
  # Remove old Docker versions
  - apt-get remove -y docker.io docker-compose docker-compose-v2 docker-doc podman-docker containerd runc || true

  # Add Docker's official GPG key
  - install -m 0755 -d /etc/apt/keyrings
  - curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  - chmod a+r /etc/apt/keyrings/docker.asc

  # Add Docker repository to Apt sources
  - |
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$UBUNTU_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

  # Update package index and install latest Docker
  - apt-get update
  - apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  # Enable and start Docker service
  - systemctl enable docker.service --now
%{ endif ~}
%{ if additional_config != "" ~}

# Additional Configuration
${additional_config}
%{ endif ~}

# Logging
output:
  all: '| tee -a /var/log/cloud-init-output.log'
