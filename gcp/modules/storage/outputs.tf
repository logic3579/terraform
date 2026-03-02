output "bucket_names" {
  description = "Map of bucket names"
  value       = { for k, v in google_storage_bucket.this : k => v.name }
}

output "bucket_urls" {
  description = "Map of bucket URLs"
  value       = { for k, v in google_storage_bucket.this : k => v.url }
}

output "bucket_iam_bindings" {
  description = "Map of bucket IAM member bindings"
  value       = { for k, v in google_storage_bucket_iam_member.this : k => { bucket = v.bucket, role = v.role, member = v.member } }
}
