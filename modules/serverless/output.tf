output "api_gateway_id" {
  value = aws_api_gateway_rest_api.items_api.id
}

output "api_gateway_stage_name" {
  value = aws_api_gateway_deployment.api_deployment.stage_name
}

output "lambda_function_name" {
  value = aws_lambda_function.item_function.function_name
}

output "lambda_function_arn" {
  value = aws_lambda_function.item_function.arn
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.items_table.name
}

output "api_gateway_base_url" {
  value = "https://${aws_api_gateway_rest_api.items_api.id}.execute-api.${var.aws_region}.amazonaws.com/prod"
}