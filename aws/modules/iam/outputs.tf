output "ec2_instance_profile_names" {
  description = "Map of EC2 instance profile alias -> actual instance profile name."
  value = {
    for k, v in aws_iam_instance_profile.ec2 : k => v.name
  }
}

output "ec2_role_arns" {
  description = "Map of EC2 role alias -> role ARN."
  value = {
    for k, v in aws_iam_role.ec2 : k => v.arn
  }
}

output "lambda_role_arns" {
  description = "Map of Lambda role alias -> role ARN."
  value = {
    for k, v in aws_iam_role.lambda : k => v.arn
  }
}

output "iam_user_arns" {
  description = "Map of IAM user name -> ARN."
  value = {
    for k, v in aws_iam_user.this : k => v.arn
  }
}

output "iam_user_names" {
  description = "Map of IAM user alias -> actual user name."
  value = {
    for k, v in aws_iam_user.this : k => v.name
  }
}
