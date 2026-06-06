variable "instances" {
  description = "EC2 instances to create. Reference subnets and security groups by their network-module keys (vpc-name/subnet-name)."
  type = list(object({
    name = string

    # Provide either ami_id directly, or use one of the os presets below for an automatic AMI lookup.
    ami_id = optional(string)
    os     = optional(string) # debian-12, al2023, ubuntu-22

    instance_type = optional(string, "t3.micro")

    subnet_name          = string                     # network module key, e.g. "vpc-name/subnet-name"
    security_group_names = optional(list(string), []) # network module keys, e.g. ["vpc-name/sg-name"]

    associate_public_ip  = optional(bool, true)
    key_name             = optional(string)
    iam_instance_profile = optional(string) # references key in var.iam_instance_profile_names
    user_data            = optional(string)

    root_volume = optional(object({
      size_gb               = optional(number, 30)
      type                  = optional(string, "gp3")
      delete_on_termination = optional(bool, true)
      encrypted             = optional(bool, true)
    }), {})

    eip = optional(bool, false)

    tags = optional(map(string), {})
  }))
  default = []

  validation {
    condition = alltrue([
      for inst in var.instances :
      inst.ami_id != null || inst.os != null
    ])
    error_message = "Each instance must set either ami_id or os."
  }

  validation {
    condition = alltrue([
      for inst in var.instances :
      inst.os == null || contains(["debian-12", "al2023", "ubuntu-22"], inst.os)
    ])
    error_message = "When set, os must be one of: debian-12, al2023, ubuntu-22."
  }
}

variable "key_pairs" {
  description = "SSH key pairs to register in this region."
  type = list(object({
    name       = string
    public_key = string
  }))
  default = []
}

variable "subnet_ids_by_name" {
  description = "Map of subnet name (vpc-name/subnet-name) -> subnet ID, supplied by the network module."
  type        = map(string)
  default     = {}
}

variable "security_group_ids_by_name" {
  description = "Map of security group name (vpc-name/sg-name) -> SG ID, supplied by the network module."
  type        = map(string)
  default     = {}
}

variable "iam_instance_profile_names" {
  description = "Map of instance-profile alias -> actual profile name, supplied by the iam module."
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
  default     = {}
}
