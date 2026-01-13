#cloud-config

# Hostname Configuration
%{ if hostname != "" ~}
hostname: ${hostname}
prefer_fqdn_over_hostname: false
%{ endif ~}

# Package Management
package_update: true
package_upgrade: true
package_reboot_if_required: false

packages:
%{ for package in packages ~}
  - ${package}
%{ endfor ~}

# Timezone Configuration
timezone: UTC

# System Configuration
preserve_hostname: false

# Logging
output:
  all: '| tee -a /var/log/cloud-init-output.log'

%{ if additional_config != "" ~}
# Additional Configuration
${additional_config}
%{ endif ~}
