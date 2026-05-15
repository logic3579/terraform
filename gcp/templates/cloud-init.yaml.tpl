#cloud-config

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

%{ if additional_config != "" ~}

# Additional Configuration
${additional_config}
%{ endif ~}

# Logging
output:
  all: '| tee -a /var/log/cloud-init-output.log'
