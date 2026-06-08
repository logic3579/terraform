output "vpcs" {
  description = "VPCs keyed by name"
  value       = vultr_vpc.this
}

output "vpc_id_by_name" {
  description = "Map of VPC name → VPC ID (used by the compute module)"
  value       = { for k, v in vultr_vpc.this : k => v.id }
}

output "firewall_groups" {
  description = "Firewall groups keyed by name"
  value       = vultr_firewall_group.this
}

output "firewall_group_id_by_name" {
  description = "Map of firewall-group name → firewall-group ID (used by the compute module)"
  value       = { for k, v in vultr_firewall_group.this : k => v.id }
}

output "firewall_rules" {
  description = "Firewall rules keyed by group-name/index"
  value       = vultr_firewall_rule.this
}
