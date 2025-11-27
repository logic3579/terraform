locals {
  # Unified naming convention
  # Example: "${var.project_id}-${var.env}-vpc"
  resource_prefix = "${var.project_id}-${var.env}"

  network_name = "${local.resource_prefix}-vpc"

  common_labels = merge(
    {
      env     = var.env
      project = var.project_id
      managed = "terraform"
    },
    var.base_labels,
  )
}
