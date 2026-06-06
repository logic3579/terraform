output "lambda_functions" {
  description = "Map of Lambda functions keyed by name."
  value = {
    for k, v in aws_lambda_function.this : k => {
      arn           = v.arn
      function_name = v.function_name
      invoke_arn    = v.invoke_arn
      version       = v.version
      runtime       = v.runtime
      handler       = v.handler
    }
  }
}

output "function_urls" {
  description = "Map of Lambda Function URLs keyed by function name."
  value = {
    for k, v in aws_lambda_function_url.this : k => {
      url                = v.function_url
      authorization_type = v.authorization_type
    }
  }
}
