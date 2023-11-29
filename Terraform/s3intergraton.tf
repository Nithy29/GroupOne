
# Creating the s3 Bucket to be used bt lambda function to upload files
resource "aws_s3_bucket" "s3Bucket" {
  bucket = "group-one-s3bucket"
}

# set ACL to own objects by the owner
resource "aws_s3_bucket_ownership_controls" "s3_Owner" {
  bucket = aws_s3_bucket.s3Bucket.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}


# Create an IAM role for Lambda execution
resource "aws_iam_role" "lambdaRun" {
  name = "lambda-run"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}


# Attache role policy to the role
resource "aws_iam_role_policy" "lambdaRunPolicy" {
  name   = "lambdaRunPolicy"
  role   = aws_iam_role.lambdaRun.name
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["s3:*", "s3-object-lambda:*"],
        Resource = "*",
      },
    ],
  })
}



# Create a Lambda function
resource "aws_lambda_function" "groupOneLambda" {
  filename      = "lambda_function.zip"
  #   source_code_hash = filebase64sha256("lambda_function_payload.zip")
  
  function_name = "groupOne-Lambda-Upload"
  role          = aws_iam_role.lambdaRun.arn
  handler       = "s3Upload.lambda_handler"
  runtime       = "python3.8"
  # timeout       = 20
  
  # Use environmnet variable - BUCKET_NAME to pass the bucket name
  environment {
    variables = {
      BUCKET_NAME = aws_s3_bucket.s3Bucket.bucket
    }
  }
}


# Attach policies to the Lambda execution role
resource "aws_iam_role_policy_attachment" "policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.lambdaRun.name
}


# Create the rest API in api gateway
resource "aws_api_gateway_rest_api" "restAPI" {
  name        = "groupOne-Upload-API"
  description = "groupOne-Upload-API Gateway"
}

# Create the api resource
resource "aws_api_gateway_resource" "apiResource" {
  rest_api_id = aws_api_gateway_rest_api.restAPI.id
  parent_id   = aws_api_gateway_rest_api.restAPI.root_resource_id
  path_part   = "Upload"
}


# Create the method
resource "aws_api_gateway_method" "apiMethod" {
  rest_api_id   = aws_api_gateway_rest_api.restAPI.id
  resource_id   = aws_api_gateway_resource.apiResource.id
  http_method   = "POST"
  authorization = "NONE"
}

# Create the intergration of the API
resource "aws_api_gateway_integration" "apiIntegration" {
  rest_api_id = aws_api_gateway_rest_api.restAPI.id
  resource_id = aws_api_gateway_resource.apiResource.id
  http_method = aws_api_gateway_method.apiMethod.http_method
  integration_http_method = "POST"
  type        = "AWS_PROXY"
  uri         = aws_lambda_function.groupOneLambda.invoke_arn
}


# Creating the method response models
resource "aws_api_gateway_method_response" "methodResponse" {
  rest_api_id = aws_api_gateway_rest_api.restAPI.id
  resource_id = aws_api_gateway_resource.apiResource.id
  http_method = aws_api_gateway_method.apiMethod.http_method
  status_code = "200"

  response_models = {
    "application/json" = "Empty",
  }
}

# Creating the intergration response models
resource "aws_api_gateway_integration_response" "intResponse" {
  depends_on     = [aws_api_gateway_integration.apiIntegration]
  rest_api_id = aws_api_gateway_rest_api.restAPI.id
  resource_id = aws_api_gateway_resource.apiResource.id
  http_method = aws_api_gateway_method.apiMethod.http_method
  status_code = aws_api_gateway_method_response.methodResponse.status_code

  response_templates = {
    "application/json" = "",
  }
}

# Add permission to lambda function allow API call
resource "aws_lambda_permission" "permission" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.groupOneLambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.restAPI.execution_arn}/*/${aws_api_gateway_method.apiMethod.http_method}/${aws_api_gateway_resource.apiResource.path_part}"
}



# Deploy the API Gateway
resource "aws_api_gateway_deployment" "deploy" {
  depends_on      = [aws_api_gateway_integration.apiIntegration]
  rest_api_id     = aws_api_gateway_rest_api.restAPI.id
  stage_name      = "prod"
}


# Output the URL of the API Gateway
output "api_gateway_url" {
  value = aws_api_gateway_deployment.deploy.invoke_url
}

