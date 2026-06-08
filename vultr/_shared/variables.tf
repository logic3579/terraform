# Shared variable declarations for all environments
# Full type definitions are in vultr/variables.tf

# ----- Provider auth -----
# Leave null (the default) and export VULTR_API_KEY in the shell — the
# Vultr provider reads that env var natively. Setting this variable in
# tfvars overrides the env-var fallback, so don't set it to a placeholder.
variable "api_key" {
  description = "Vultr API key — see https://my.vultr.com/settings/#settingsapi. Falls back to VULTR_API_KEY env var when null."
  type        = string
  sensitive   = true
  default     = null
}

variable "rate_limit" {
  description = "Milliseconds between API calls (Vultr caps at 30/s ≈ 33ms minimum)"
  type        = number
  default     = 500
}

variable "retry_limit" {
  description = "Number of retries on failed API calls"
  type        = number
  default     = 3
}

# ----- Resource inputs (full types in vultr/variables.tf) -----
variable "vpcs" {
  type    = any
  default = []
}

variable "firewall_groups" {
  type    = any
  default = []
}

variable "ssh_keys" {
  type    = any
  default = []
}

variable "startup_scripts" {
  type    = any
  default = []
}

variable "instances" {
  type    = any
  default = []
}
