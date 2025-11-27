output "service_accounts" {
  description = "Service accounts created by this module"
  value = [
    for sa in google_service_account.this : {
      account_id = sa.account_id
      email      = sa.email
      name       = sa.name
    }
  ]
}
