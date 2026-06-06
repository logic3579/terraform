variable "budgets" {
  description = "AWS Budgets to create, with one or more email notifications each."
  type = list(object({
    name         = string
    budget_type  = optional(string, "COST") # COST, USAGE, RI_UTILIZATION, etc.
    limit_amount = string                   # AWS expects a string here
    limit_unit   = optional(string, "USD")
    time_unit    = optional(string, "MONTHLY") # DAILY, MONTHLY, QUARTERLY, ANNUALLY

    cost_filters = optional(map(list(string)), {})

    notifications = list(object({
      comparison_operator        = optional(string, "GREATER_THAN") # GREATER_THAN, LESS_THAN, EQUAL_TO
      threshold                  = number
      threshold_type             = optional(string, "PERCENTAGE") # PERCENTAGE or ABSOLUTE_VALUE
      notification_type          = optional(string, "ACTUAL")     # ACTUAL or FORECASTED
      subscriber_email_addresses = list(string)
    }))

    tags = optional(map(string), {})
  }))
  default = []

  validation {
    condition = alltrue([
      for b in var.budgets : contains(["DAILY", "MONTHLY", "QUARTERLY", "ANNUALLY"], coalesce(b.time_unit, "MONTHLY"))
    ])
    error_message = "time_unit must be one of: DAILY, MONTHLY, QUARTERLY, ANNUALLY."
  }

  validation {
    condition = alltrue(flatten([
      for b in var.budgets : [
        for n in b.notifications :
        contains(["ACTUAL", "FORECASTED"], coalesce(n.notification_type, "ACTUAL"))
      ]
    ]))
    error_message = "notification_type must be ACTUAL or FORECASTED."
  }

  validation {
    condition = alltrue(flatten([
      for b in var.budgets : [
        for n in b.notifications :
        contains(["PERCENTAGE", "ABSOLUTE_VALUE"], coalesce(n.threshold_type, "PERCENTAGE"))
      ]
    ]))
    error_message = "threshold_type must be PERCENTAGE or ABSOLUTE_VALUE."
  }
}

variable "tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
  default     = {}
}
