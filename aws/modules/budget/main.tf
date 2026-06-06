resource "aws_budgets_budget" "this" {
  for_each = { for b in var.budgets : b.name => b }

  name         = each.value.name
  budget_type  = each.value.budget_type
  limit_amount = each.value.limit_amount
  limit_unit   = each.value.limit_unit
  time_unit    = each.value.time_unit

  dynamic "cost_filter" {
    for_each = coalesce(each.value.cost_filters, {})
    content {
      name   = cost_filter.key
      values = cost_filter.value
    }
  }

  dynamic "notification" {
    for_each = each.value.notifications
    content {
      comparison_operator        = coalesce(notification.value.comparison_operator, "GREATER_THAN")
      threshold                  = notification.value.threshold
      threshold_type             = coalesce(notification.value.threshold_type, "PERCENTAGE")
      notification_type          = coalesce(notification.value.notification_type, "ACTUAL")
      subscriber_email_addresses = notification.value.subscriber_email_addresses
    }
  }

  tags = merge(var.tags, each.value.tags, {
    Name = each.value.name
  })
}
