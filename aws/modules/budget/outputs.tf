output "budgets" {
  description = "Map of Budgets keyed by name."
  value = {
    for k, v in aws_budgets_budget.this : k => {
      id           = v.id
      arn          = v.arn
      name         = v.name
      budget_type  = v.budget_type
      time_unit    = v.time_unit
      limit_amount = v.limit_amount
    }
  }
}
