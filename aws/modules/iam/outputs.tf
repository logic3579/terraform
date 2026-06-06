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
