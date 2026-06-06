output "rds_instances" {
  description = "Map of RDS instances keyed by name. Master password is in SSM Parameter Store (see ssm_password_path)."
  value = {
    for k, v in aws_db_instance.this : k => {
      id                = v.id
      arn               = v.arn
      endpoint          = v.endpoint
      address           = v.address
      port              = v.port
      db_name           = v.db_name
      username          = v.username
      engine            = v.engine
      engine_version    = v.engine_version
      ssm_password_path = aws_ssm_parameter.master_password[k].name
    }
  }
}

output "ssm_password_parameters" {
  description = "Map of SSM Parameter Store paths keyed by RDS instance name."
  value = {
    for k, v in aws_ssm_parameter.master_password : k => {
      name = v.name
      arn  = v.arn
    }
  }
}
