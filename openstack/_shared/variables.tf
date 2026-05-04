# Shared variable declarations for all environments
# Full type definitions are in openstack/variables.tf

# ----- Provider auth (Keystone v3) -----
variable "auth_url" {
  description = "Keystone v3 endpoint, e.g. https://keystone.example.com:5000/v3"
  type        = string
}

variable "region" {
  description = "OpenStack region"
  type        = string
  default     = "RegionOne"
}

variable "user_name" {
  description = "OpenStack username"
  type        = string
}

variable "password" {
  description = "OpenStack password"
  type        = string
  sensitive   = true
}

variable "tenant_name" {
  description = "Project (tenant) name"
  type        = string
}

variable "user_domain_name" {
  description = "User's domain name (Keystone v3)"
  type        = string
  default     = "Default"
}

variable "project_domain_name" {
  description = "Project's domain name (Keystone v3)"
  type        = string
  default     = "Default"
}

variable "insecure" {
  description = "Skip TLS verification on OpenStack API endpoints"
  type        = bool
  default     = false
}

# ----- Resource inputs (full types in openstack/variables.tf) -----
variable "networks" {
  type    = any
  default = []
}

variable "routers" {
  type    = any
  default = []
}

variable "security_groups" {
  type    = any
  default = []
}

variable "floating_ips" {
  type    = any
  default = []
}

variable "keypairs" {
  type    = any
  default = []
}

variable "instances" {
  type    = any
  default = []
}

variable "volumes" {
  type    = any
  default = []
}
