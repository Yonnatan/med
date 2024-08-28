# DynamoDB Table Definition
# Used by: Lambda function to store and retrieve items
resource "aws_dynamodb_table" "items_table" {
  name         = var.table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "ItemId"

  attribute {
    name = "ItemId"
    type = "S"
  }
}

# IAM Role for Lambda Execution
# Used by: Lambda function to execute with necessary permissions
resource "aws_iam_role" "lambda_exec" {
  name = "lambda_exec_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

# IAM Role Policy Attachment for Lambda Basic Execution
# Used by: Lambda function to interact with AWS services
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# IAM Policy for DynamoDB Access
# Used by: Lambda function to access DynamoDB
resource "aws_iam_policy" "dynamodb_access" {
  name = "dynamodb_access_policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem"]
      Effect   = "Allow"
      Resource = aws_dynamodb_table.items_table.arn
    }]
  })
}

# IAM Role Policy Attachment for DynamoDB Access
# Used by: Lambda function to assume the DynamoDB access policy
resource "aws_iam_role_policy_attachment" "dynamodb_access" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.dynamodb_access.arn
}

# Lambda Function Definition
# Used by: API Gateway to invoke and process requests
resource "aws_lambda_function" "item_function" {
  filename         = "${path.module}/lambda_function.zip"
  function_name    = "ItemFunction"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.9"
  source_code_hash = filebase64sha256("${path.module}/lambda_function.zip")
  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.items_table.name
    }
  }
}

# API Gateway REST API Definition
# Used by: API Gateway to expose Lambda function as an HTTP API
resource "aws_api_gateway_rest_api" "items_api" {
  name        = "ItemsAPI"
  description = "API for managing items in DynamoDB"
}

# API Gateway Resource for "/items" Path
# Used by: API Gateway to define the base resource path
resource "aws_api_gateway_resource" "items" {
  rest_api_id = aws_api_gateway_rest_api.items_api.id
  parent_id   = aws_api_gateway_rest_api.items_api.root_resource_id
  path_part   = "items"
}

# API Gateway POST Method Definition for "/items"
# Used by: API Gateway to define the POST method on the "/items" resource
resource "aws_api_gateway_method" "post_method" {
  rest_api_id   = aws_api_gateway_rest_api.items_api.id
  resource_id   = aws_api_gateway_resource.items.id
  http_method   = "POST"
  authorization = "NONE"
}

# API Gateway Integration for POST Method
# Used by: API Gateway to integrate the POST method with the Lambda function
resource "aws_api_gateway_integration" "post_integration" {
  rest_api_id             = aws_api_gateway_rest_api.items_api.id
  resource_id             = aws_api_gateway_resource.items.id
  http_method             = aws_api_gateway_method.post_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.item_function.invoke_arn
}

# API Gateway Resource for "/items/{id}" Path
# Used by: API Gateway to define a resource with a dynamic ID path
resource "aws_api_gateway_resource" "item" {
  rest_api_id = aws_api_gateway_rest_api.items_api.id
  parent_id   = aws_api_gateway_resource.items.id
  path_part   = "{id}"
}

# API Gateway GET Method Definition for "/items/{id}"
# Used by: API Gateway to define the GET method on the "/items/{id}" resource
resource "aws_api_gateway_method" "get_method" {
  rest_api_id   = aws_api_gateway_rest_api.items_api.id
  resource_id   = aws_api_gateway_resource.item.id
  http_method   = "GET"
  authorization = "NONE"
}

# API Gateway Integration for GET Method
# Used by: API Gateway to integrate the GET method with the Lambda function
resource "aws_api_gateway_integration" "get_integration" {
  rest_api_id             = aws_api_gateway_rest_api.items_api.id
  resource_id             = aws_api_gateway_resource.item.id
  http_method             = aws_api_gateway_method.get_method.http_method
  integration_http_method = "POST" # Lambda proxy integration uses POST
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.item_function.invoke_arn
}

# API Gateway DELETE Method Definition for "/items/{id}"
# Used by: API Gateway to define the DELETE method on the "/items/{id}" resource
resource "aws_api_gateway_method" "delete_method" {
  rest_api_id   = aws_api_gateway_rest_api.items_api.id
  resource_id   = aws_api_gateway_resource.item.id
  http_method   = "DELETE"
  authorization = "NONE"
}

# API Gateway Integration for DELETE Method
# Used by: API Gateway to integrate the DELETE method with the Lambda function
resource "aws_api_gateway_integration" "delete_integration" {
  rest_api_id             = aws_api_gateway_rest_api.items_api.id
  resource_id             = aws_api_gateway_resource.item.id
  http_method             = aws_api_gateway_method.delete_method.http_method
  integration_http_method = "POST" # Lambda proxy integration uses POST
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.item_function.invoke_arn
}

# API Gateway Deployment Definition
# Used by: API Gateway to deploy the API to a specific stage
resource "aws_api_gateway_deployment" "api_deployment" {
  depends_on = [
    aws_api_gateway_integration.post_integration,
    aws_api_gateway_integration.get_integration,
    aws_api_gateway_integration.delete_integration,
  ]
  rest_api_id = aws_api_gateway_rest_api.items_api.id
}

# API Gateway Stage Definition with Logs and Tracing Enabled
# Used by: API Gateway to define the "prod" stage with CloudWatch logs and X-Ray tracing enabled
resource "aws_api_gateway_stage" "prod_stage" {
  depends_on = [
    aws_api_gateway_deployment.api_deployment,
    aws_api_gateway_account.api_gw_account,
    aws_iam_role_policy_attachment.api_gw_cloudwatch_policy
  ]
  deployment_id = aws_api_gateway_deployment.api_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.items_api.id
  stage_name    = "prod"

  # Enable CloudWatch Logs and Tracing
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gw_logs.arn
    format          = "$context.requestId $context.extendedRequestId $context.identity.sourceIp $context.identity.caller $context.identity.user $context.identity.userAgent $context.requestTime $context.status $context.protocol $context.responseLength $context.path $context.resourcePath $context.httpMethod $context.apiId"
  }

  xray_tracing_enabled = true
  # Force Enable Cloudwatch Logs
  variables = {
    "loggingLevel"     = "INFO"
    "dataTraceEnabled" = "true"
  }
}


# Lambda Permission for API Gateway Invocation
# Used by: API Gateway to invoke the Lambda function
resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.item_function.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.items_api.execution_arn}/*/*"
}

# CloudWatch Log Group for API Gateway
# Used by: API Gateway to log requests and responses
resource "aws_cloudwatch_log_group" "api_gw_logs" {
  name              = "/aws/api-gateway/${aws_api_gateway_rest_api.items_api.name}"
  retention_in_days = 7
}

# API Gateway Account Configuration for CloudWatch Logs
# Used by: API Gateway to push logs to CloudWatch
resource "aws_api_gateway_account" "api_gw_account" {
  cloudwatch_role_arn = aws_iam_role.api_gw_cloudwatch_role.arn
}

# IAM Role for API Gateway CloudWatch Logs
# Used by: API Gateway to assume role for pushing logs to CloudWatch
resource "aws_iam_role" "api_gw_cloudwatch_role" {
  name = "api_gw_cloudwatch_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "apigateway.amazonaws.com" }
    }]
  })
}

# IAM Role Policy Attachment for CloudWatch Logs
# Used by: API Gateway to push logs to CloudWatch
resource "aws_iam_role_policy_attachment" "api_gw_cloudwatch_policy" {
  role       = aws_iam_role.api_gw_cloudwatch_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

# API Gateway Method Definition
# Used by API Gateway to Define HTTP Methods for API Endpoints

resource "aws_api_gateway_method_settings" "all" {
  rest_api_id = aws_api_gateway_rest_api.items_api.id
  stage_name  = aws_api_gateway_stage.prod_stage.stage_name
  method_path = "*/*"

  settings {
    metrics_enabled        = true
    logging_level          = "INFO"
    data_trace_enabled     = true
    throttling_burst_limit = 5000
    throttling_rate_limit  = 10000
  }
}
