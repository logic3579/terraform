# Shared variable declarations for all environments
# Full type definitions are in proxmox/variables.tf
# Values are provided via terraform.tfvars

# ----- Provider auth -----
variable "endpoint" {
  description = "Proxmox VE API endpoint, e.g. https://pve.example.com:8006/"
  type        = string
}

variable "insecure" {
  description = "Skip TLS verification on the Proxmox API"
  type        = bool
  default     = false
}

variable "api_token" {
  description = "API token in 'user@realm!tokenid=secret' form (preferred over username/password)"
  type        = string
  default     = null
  sensitive   = true
}

variable "username" {
  description = "Username (e.g. root@pam) — used when api_token is not set"
  type        = string
  default     = null
}

variable "password" {
  description = "Password — used when api_token is not set"
  type        = string
  default     = null
  sensitive   = true
}

# ----- SSH (only required when uploading snippets to a node) -----
variable "ssh_agent" {
  description = "Use ssh-agent for SSH operations"
  type        = bool
  default     = false
}

variable "ssh_username" {
  description = "SSH username on PVE nodes (e.g. root). Leave null to disable the ssh block."
  type        = string
  default     = null
}

variable "ssh_private_key" {
  description = "SSH private key (PEM) for connecting to PVE nodes"
  type        = string
  default     = null
  sensitive   = true
}

# ----- Resource inputs (full type defs in proxmox/variables.tf) -----
variable "bridges" {
  description = "Linux bridges"
  type        = any
  default     = []
}

variable "download_files" {
  description = "ISOs / images downloaded to PVE datastores"
  type        = any
  default     = []
}

variable "vms" {
  description = "KVM virtual machines"
  type        = any
  default     = []
}
