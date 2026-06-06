# ============================================================
# Locals
# ============================================================

locals {
  lambdas_by_name = { for f in var.lambda_functions : f.name => f }

  lambdas_with_url = {
    for f in var.lambda_functions : f.name => f
    if f.function_url != null && coalesce(f.function_url.enabled, true)
  }
}

# ============================================================
# Source code packaging — zip a local directory per function
#
# Paths resolve relative to the root module (env dir), so tfvars can use
# `source_dir = "lambda-src"` and place the code under envs/<env>/lambda-src/.
# ============================================================

data "archive_file" "this" {
  for_each = local.lambdas_by_name

  type        = "zip"
  source_dir  = "${path.root}/${each.value.source_dir}"
  output_path = "${path.root}/.terraform/tmp/${each.value.name}.zip"
}

# ============================================================
# Lambda function
# ============================================================

resource "aws_lambda_function" "this" {
  for_each = local.lambdas_by_name

  function_name = each.value.name
  role          = var.lambda_role_arns[each.value.role_name]
  runtime       = each.value.runtime
  handler       = each.value.handler
  memory_size   = each.value.memory_mb
  timeout       = each.value.timeout_s
  architectures = [each.value.architecture]

  filename         = data.archive_file.this[each.key].output_path
  source_code_hash = data.archive_file.this[each.key].output_base64sha256

  dynamic "environment" {
    for_each = length(coalesce(each.value.environment_variables, {})) > 0 ? [1] : []
    content {
      variables = each.value.environment_variables
    }
  }

  tags = merge(var.tags, each.value.tags, {
    Name = each.value.name
  })
}

# ============================================================
# Function URL (optional, per-function)
# ============================================================

resource "aws_lambda_function_url" "this" {
  for_each = local.lambdas_with_url

  function_name      = aws_lambda_function.this[each.key].function_name
  authorization_type = coalesce(each.value.function_url.auth_type, "AWS_IAM")

  dynamic "cors" {
    for_each = each.value.function_url.cors != null ? [each.value.function_url.cors] : []
    content {
      allow_origins = cors.value.allow_origins
      allow_methods = cors.value.allow_methods
      allow_headers = cors.value.allow_headers
      max_age       = cors.value.max_age
    }
  }
}
