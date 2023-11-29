
# ------------------------------------------------------------------------------
# Creation of glue job and role to run glue job
# ------------------------------------------------------------------------------

# Crering the glue job
resource "aws_glue_job" "glue_job" {
  name = "GroupOneGetData"
  role_arn = aws_iam_role.glue_role.arn
  glue_version  = "4.0" 

  # Specify the location of the script 
  command {
    name = "glueetl"
    script_location = "s3://aws-glue-assets-411658317626-ca-central-1/scripts/G.py"
  }
  
#   Set default job parameters
  default_arguments = {
    "--job-bookmark-option": "job-bookmark-enable",
    "--enable-metrics": "true",
    "--enable-continuous-cloudwatch-log": "",
    "--enable-continuous-log-filter": "true",
    "--enable-job-insights" : "true",
    "--enable-spark-ui" : "true"
    "--spark-event-logs-path" : "s3://aws-glue-assets-411658317626-ca-central-1/sparkHistoryLogs/"
  }
}

# Create the glue job role
resource "aws_iam_role" "glue_role" {
  name = "groupOneGlueRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "glue.amazonaws.com"
        }
      }
    ]
  }) 
}

# Attach default policy to role
resource "aws_iam_role_policy_attachment" "role_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
  role = aws_iam_role.glue_role.name
}


# ------------------------------------------------------------------------------
# Creation of lambda and roles
# ------------------------------------------------------------------------------

# Create an IAM role for Lambda execution
resource "aws_iam_role" "lambda_execution_role" {
  name = "group_one_lambda_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}


# Create a Lambda function
resource "aws_lambda_function" "invoke_glue_job" {
  function_name = "GroupOneStartGlueJob"
  runtime       = "python3.8"
  handler       = "StartGlueJob.lambda_handler"
  role          = aws_iam_role.lambda_execution_role.arn
  filename      = "StartGlueJob.zip"

  environment {
    variables = {
      GLUE_JOB_NAME = aws_glue_job.glue_job.name   #"GroupGetData"
    }
  }
}


# Attache role policy to the role
resource "aws_iam_role_policy" "lambdaInvokePolicy" {
  name   = "groupOnelambdaRunPolicy"
  role   = aws_iam_role.lambda_execution_role.name
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
                    "glue:*",
                    "s3:GetBucketLocation",
                    "s3:ListBucket",
                    "s3:ListAllMyBuckets",
                    "s3:GetBucketAcl",
                    "ec2:DescribeVpcEndpoints",
                    "ec2:DescribeRouteTables",
                    "ec2:CreateNetworkInterface",
                    "ec2:DeleteNetworkInterface",
                    "ec2:DescribeNetworkInterfaces",
                    "ec2:DescribeSecurityGroups",
                    "ec2:DescribeSubnets",
                    "ec2:DescribeVpcAttribute",
                    "iam:ListRolePolicies",
                    "iam:GetRole",
                    "iam:GetRolePolicy",
                    "cloudwatch:PutMetricData"
                   ],
        Resource = "*",
      },
    ],
  })
}



# Attach policies to the Lambda execution role (adjust as needed)
resource "aws_iam_role_policy_attachment" "lambda_execution_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.lambda_execution_role.name
}


# ------------------------------------------------------------------------------
# Creation of API Gateway
# ------------------------------------------------------------------------------

# Create an API Gateway
resource "aws_api_gateway_rest_api" "restAPIStart" {
  name        = "groupOneStartGlueJob"
  description = "My API Gateway"
}

# Create a resource in the API Gateway
resource "aws_api_gateway_resource" "apiResourceStart" {
  rest_api_id = aws_api_gateway_rest_api.restAPIStart.id
  parent_id   = aws_api_gateway_rest_api.restAPIStart.root_resource_id
  path_part   = "invoke"
}

# Create a POST method for the resource
resource "aws_api_gateway_method" "methodAPI" {
  rest_api_id   = aws_api_gateway_rest_api.restAPIStart.id
  resource_id   = aws_api_gateway_resource.apiResourceStart.id
  http_method   = "POST"
  authorization = "NONE"
}

# Connect the method to the Lambda function
resource "aws_api_gateway_integration" "apiIntergration" {
  rest_api_id             = aws_api_gateway_rest_api.restAPIStart.id
  resource_id             = aws_api_gateway_resource.apiResourceStart.id
  http_method             = aws_api_gateway_method.methodAPI.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.invoke_glue_job.invoke_arn
}





# Deploy the API Gateway
resource "aws_api_gateway_deployment" "deployStartJob" {
  depends_on  = [aws_api_gateway_integration.apiIntergration]
  rest_api_id = aws_api_gateway_rest_api.restAPIStart.id
  stage_name  = "prod"
}


resource "aws_lambda_permission" "permissionStartJob" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.invoke_glue_job.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.restAPIStart.execution_arn}/*/${aws_api_gateway_method.methodAPI.http_method}/${aws_api_gateway_resource.apiResourceStart.path_part}"
}

# Output the URL of the API Gateway
# output "api_gateway_url" {
#   value = aws_api_gateway_deployment.deploy.invoke_url
# }
