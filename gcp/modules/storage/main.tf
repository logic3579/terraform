locals {
  bucket_iam_members = flatten([
    for bucket in var.buckets : [
      for binding in coalesce(bucket.iam_bindings, []) : [
        for member in binding.members : {
          bucket = bucket.name
          role   = binding.role
          member = member
        }
      ]
    ]
  ])
}

resource "google_storage_bucket" "this" {
  for_each = { for b in var.buckets : b.name => b }

  project                     = var.project_id
  name                        = each.value.name
  location                    = each.value.location
  storage_class               = coalesce(each.value.storage_class, "STANDARD")
  uniform_bucket_level_access = true
  public_access_prevention    = coalesce(each.value.public_access_prevention, "enforced")

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
        age            = lifecycle_rule.value.condition.age
        with_state     = lifecycle_rule.value.condition.with_state
        matches_prefix = lifecycle_rule.value.condition.matches_prefix
      }
    }
  }
}

resource "google_storage_bucket_iam_member" "this" {
  for_each = { for m in local.bucket_iam_members : "${m.bucket}/${m.role}/${m.member}" => m }

  bucket = google_storage_bucket.this[each.value.bucket].name
  role   = each.value.role
  member = each.value.member
}
