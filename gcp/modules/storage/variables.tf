variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "labels" {
  description = "Labels to apply to all buckets"
  type        = map(string)
  default     = {}
}

variable "buckets" {
  description = "List of GCS buckets to create"
  type = list(object({
    name                     = string
    location                 = string
    storage_class            = optional(string)
    public_access_prevention = optional(string)
    versioning_enabled       = optional(bool)
    labels                   = optional(map(string))
    lifecycle_rules = optional(list(object({
      action = object({
        type          = string
        storage_class = optional(string)
      })
      condition = object({
        age        = optional(number)
        with_state = optional(string)
      })
    })))
  }))
  default = []
}
