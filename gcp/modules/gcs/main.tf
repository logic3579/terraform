resource "google_storage_bucket" "this" {
  for_each = { for b in var.gcs_buckets : b.name => b }

  project                     = var.project_id
  name                        = each.value.name
  location                    = each.value.location
  storage_class               = coalesce(each.value.storage_class, "STANDARD")
  uniform_bucket_level_access = true
  public_access_prevention    = coalesce(each.value.public_access_prevention, "null")

  versioning {
    enabled = coalesce(each.value.versioning_enabled, false)
  }

  labels = merge(var.labels, each.value.labels)

  dynamic "lifecycle_rule" {
    for_each = coalesce(each.value.lifecycle_rules, [])
    content {
      action {
        type          = lifecycle_rule.value.action.type
        storage_class = lifecycle_rule.value.action.storage_class
      }
      condition {
        age        = lifecycle_rule.value.condition.age
        with_state = lifecycle_rule.value.condition.with_state
      }
    }
  }
}
