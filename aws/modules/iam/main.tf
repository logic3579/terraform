# ============================================================
# Assume-role policy documents
# ============================================================

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# ============================================================
# Locals — flatten role-to-policy attachments
# ============================================================

locals {
  ec2_policy_attachments = {
    for entry in flatten([
      for r in var.ec2_instance_profiles : [
        for arn in coalesce(r.managed_policy_arns, []) : {
          key  = "${r.name}/${arn}"
          role = r.name
          arn  = arn
        }
      ]
    ]) : entry.key => entry
  }

  lambda_policy_attachments = {
    for entry in flatten([
      for r in var.lambda_execution_roles : [
        for arn in coalesce(r.managed_policy_arns, []) : {
          key  = "${r.name}/${arn}"
          role = r.name
          arn  = arn
        }
      ]
    ]) : entry.key => entry
  }

  ec2_inline_policies = {
    for entry in flatten([
      for r in var.ec2_instance_profiles : [
        for policy_name, policy_json in coalesce(r.inline_policies, {}) : {
          key         = "${r.name}/${policy_name}"
          role        = r.name
          policy_name = policy_name
          policy_json = policy_json
        }
      ]
    ]) : entry.key => entry
  }

  lambda_inline_policies = {
    for entry in flatten([
      for r in var.lambda_execution_roles : [
        for policy_name, policy_json in coalesce(r.inline_policies, {}) : {
          key         = "${r.name}/${policy_name}"
          role        = r.name
          policy_name = policy_name
          policy_json = policy_json
        }
      ]
    ]) : entry.key => entry
  }
}

# ============================================================
# EC2 roles + instance profiles
# ============================================================

resource "aws_iam_role" "ec2" {
  for_each = { for r in var.ec2_instance_profiles : r.name => r }

  name               = each.value.name
  description        = each.value.description
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = merge(var.tags, each.value.tags, {
    Name = each.value.name
  })
}

resource "aws_iam_instance_profile" "ec2" {
  for_each = { for r in var.ec2_instance_profiles : r.name => r }

  name = each.value.name
  role = aws_iam_role.ec2[each.key].name

  tags = merge(var.tags, each.value.tags)
}

resource "aws_iam_role_policy_attachment" "ec2_managed" {
  for_each = local.ec2_policy_attachments

  role       = aws_iam_role.ec2[each.value.role].name
  policy_arn = each.value.arn
}

resource "aws_iam_role_policy" "ec2_inline" {
  for_each = local.ec2_inline_policies

  name   = each.value.policy_name
  role   = aws_iam_role.ec2[each.value.role].name
  policy = each.value.policy_json
}

# ============================================================
# Lambda execution roles
# ============================================================

resource "aws_iam_role" "lambda" {
  for_each = { for r in var.lambda_execution_roles : r.name => r }

  name               = each.value.name
  description        = each.value.description
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json

  tags = merge(var.tags, each.value.tags, {
    Name = each.value.name
  })
}

resource "aws_iam_role_policy_attachment" "lambda_managed" {
  for_each = local.lambda_policy_attachments

  role       = aws_iam_role.lambda[each.value.role].name
  policy_arn = each.value.arn
}

resource "aws_iam_role_policy" "lambda_inline" {
  for_each = local.lambda_inline_policies

  name   = each.value.policy_name
  role   = aws_iam_role.lambda[each.value.role].name
  policy = each.value.policy_json
}
