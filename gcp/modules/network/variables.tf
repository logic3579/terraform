variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "network_name" {
  description = "VPC network name"
  type        = string
}

variable "subnets" {
  description = "List of subnet configurations"
  type = list(object({
    name   = string
    cidr   = string
    region = string
  }))
}

variable "labels" {
  description = "Labels applied to network and subnets"
  type        = map(string)
  default     = {}
}
