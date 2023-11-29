
# ------------------------------------------------------------------------------
# Creation of DynamoDB
# ------------------------------------------------------------------------------

resource "aws_dynamodb_table" "my_table" {
  name           = "groupOneMyTable"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"
  attribute {
    name = "id"
    type = "S"
  }
  stream_enabled = false
}


# ------------------------------------------------------------------------------
# Creation of API gate way related objects
# ------------------------------------------------------------------------------

# API Gateway
resource "aws_api_gateway_rest_api" "my_api" {
  name        = "GroupOneDBapi"
  description = "My API Gateway"
}

# Creating api resource
resource "aws_api_gateway_resource" "my_resource" {
  rest_api_id = aws_api_gateway_rest_api.my_api.id
  parent_id   = aws_api_gateway_rest_api.my_api.root_resource_id
  path_part   = "data"
}

# Creating the api method - POST
resource "aws_api_gateway_method" "my_method" {
  rest_api_id   = aws_api_gateway_rest_api.my_api.id
  resource_id   = aws_api_gateway_resource.my_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

# Intergrating the api
resource "aws_api_gateway_integration" "my_integration" {
  rest_api_id             = aws_api_gateway_rest_api.my_api.id
  resource_id             = aws_api_gateway_resource.my_resource.id
  http_method             = aws_api_gateway_method.my_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.my_lambda.invoke_arn
}

# Deploying the created api
resource "aws_api_gateway_deployment" "my_deployment" {
  depends_on = [aws_api_gateway_integration.my_integration]

  rest_api_id = aws_api_gateway_rest_api.my_api.id
  stage_name  = "prod"
}


# ------------------------------------------------------------------------------
# Creation of Lambda related objects
# ------------------------------------------------------------------------------

# Creating the lambda function
resource "aws_lambda_function" "my_lambda" {
  filename      = "DB_CRUD.zip"
  function_name = "group1-db-lambda-function"
  role          = "arn:aws:iam::411658317626:role/grp1-lambda-apigateway-role"
  handler       = "DB_CRUD.lambda_handler"
  runtime       = "python3.8"

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.my_table.name
    }
  }
}


# Allowing lambda to be called by API
resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "AllowExecutionFromAPIGatewayDynamoDBGrp1"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.my_lambda.function_name
  principal     = "apigateway.amazonaws.com"

  # Adjust the source ARN accordingly
  source_arn = "${aws_api_gateway_rest_api.my_api.execution_arn}/*/${aws_api_gateway_method.my_method.http_method}/${aws_api_gateway_resource.my_resource.path_part}"
  # "arn:aws:execute-api:us-east-1:411658317626:${aws_api_gateway_rest_api.my_api.id}/*/${aws_api_gateway_method.my_method.http_method}/${aws_api_gateway_resource.my_resource.path_part}"
  
}



# Output the API Gateway Invoke URL
output "api_gateway_url" {
  value = aws_api_gateway_deployment.my_deployment.invoke_url
}
