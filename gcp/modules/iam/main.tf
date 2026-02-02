resource "google_service_account" "this" {
  for_each     = { for sa in var.service_accounts : sa.account_id => sa }
  project      = var.project_id
  account_id   = each.value.account_id
  display_name = coalesce(each.value.display_name, each.value.account_id)
  description  = coalesce(each.value.description, "Managed by Terraform")
}

locals {
  flat_bindings = flatten([
    for ib in var.iam_bindings : [
      for r in ib.roles : {
        key   = "${r}:${ib.service_account_email}"
        role  = r
        email = ib.service_account_email
      }
    ]
  ])
}

resource "google_project_iam_member" "this" {
  for_each = {
    for fb in local.flat_bindings : fb.key => fb
  }

  project = var.project_id
  role    = each.value.role
  member  = "serviceAccount:${each.value.email}"
}

# Workload Identity bindings - allow KSA to impersonate GSA
resource "google_service_account_iam_member" "workload_identity" {
  for_each = {
    for wi in var.workload_identity_bindings :
    "${wi.service_account_id}:${wi.namespace}:${wi.ksa_name}" => wi
  }

  service_account_id = google_service_account.this[each.value.service_account_id].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${each.value.wi_pool_project_id}.svc.id.goog[${each.value.namespace}/${each.value.ksa_name}]"
}
