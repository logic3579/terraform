variable "volumes" {
  type = list(object({
    name              = string
    description       = optional(string)
    size              = number
    volume_type       = optional(string)
    availability_zone = optional(string)
    image_name        = optional(string)
    metadata          = optional(map(string), {})
  }))
  default = []
}
