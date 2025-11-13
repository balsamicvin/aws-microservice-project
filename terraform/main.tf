# DynamoDB table to define database and optimize costs.
resource "aws_dynamodb_table" "inventory_table" {
  name              = "${var.project_name}-inventory-table"
  hash_key          = "id"
  billing_mode      = "PAY_PER_REQUEST"

  attribute {
    name = "id"
    type = "S" # S for String
  }

  tags = {
    Name = "${var.project_name}-inventory-table"
  }
}

# ECR Repository for containerization.
resource "aws_ecr_repository" "inventory_repo" {
  name                 = "inventory-api-repo" # Must match ECR_REPOSITORY in deploy.yml
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

# IAM Role & Policy Document that defines the precise permissions for Least Privilege (POLP)
data "aws_iam_policy_document" "lambda_policy_document" {
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    # Allow logging to CloudWatch for debugging
    resources = ["arn:aws:logs:*:*:*"]
    effect    = "Allow"
  }

  statement {
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:DeleteItem",
      "dynamodb:Scan",
      "dynamodb:ListTables" # Added for robustness, as discussed previously
    ]
    # CRUCIAL: Restrict access ONLY to the specific DynamoDB ARN
    resources = [aws_dynamodb_table.inventory_table.arn]
    effect    = "Allow"
  }

  statement {
    actions = [
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchCheckLayerAvailability"
    ]
    # CRUCIAL: Allow pulling the image ONLY from the specific ECR repo
    resources = [aws_ecr_repository.inventory_repo.arn]
    effect    = "Allow"
  }
}

# The IAM Policy resource
resource "aws_iam_policy" "lambda_policy" {
  name   = "${var.project_name}-lambda-policy"
  policy = data.aws_iam_policy_document.lambda_policy_document.json
}

# The IAM Role that the Lambda service can assume
resource "aws_iam_role" "lambda_exec_role" {
  name               = "${var.project_name}-lambda-exec-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        # CRUCIAL: Allow only the Lambda service to assume this role
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })
}

# Attach the custom policy to the execution role
resource "aws_iam_role_policy_attachment" "lambda_attach" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

# AWS Lambda function for container image and compute.
resource "aws_lambda_function" "inventory_lambda" {
  function_name = "${var.project_name}-inventory-lambda"
  role          = aws_iam_role.lambda_exec_role.arn
  timeout       = 10

  # CRUCIAL: Use the image tag passed from the CI/CD pipeline variable
  image_uri    = "${aws_ecr_repository.inventory_repo.repository_url}:${var.image_tag}"
  package_type = "Image"

  # CRUCIAL: Pass the DynamoDB table name to the Python code via an environment variable
  environment {
    variables = {
      INVENTORY_TABLE_NAME = aws_dynamodb_table.inventory_table.name
    }
  }

  tags = {
    Name = "${var.project_name}-inventory-lambda"
  }
}

# --- API GATEWAY RESOURCES (Reordered for correct dependency) ---

# 1. Create the HTTP API Gateway (Reference is made to this next)
resource "aws_apigatewayv2_api" "inventory_api" {
  name          = "${var.project_name}-inventory-api"
  protocol_type = "HTTP"
}

# 2. Define the integration that links the API Gateway to the Lambda function (References the API and Lambda)
resource "aws_apigatewayv2_integration" "inventory_integration" {
  api_id                 = aws_apigatewayv2_api.inventory_api.id
  integration_type       = "AWS_PROXY"
  integration_method     = "POST"
  integration_uri        = aws_lambda_function.inventory_lambda.invoke_arn
  payload_format_version = "2.0" # Use v2.0 for simpler Lambda integration payload
}

# 3. Define the route (References the API and the Integration)
resource "aws_apigatewayv2_route" "inventory_route" {
  api_id    = aws_apigatewayv2_api.inventory_api.id
  # FIX: Setting the correct path for CRUD operations
  route_key = "ANY /items/{proxy+}" 
  target    = "integrations/${aws_apigatewayv2_integration.inventory_integration.id}"
}

# 4. Deploy the API (References the API)
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.inventory_api.id
  name        = "$default"
  auto_deploy = true
}

# AWS Lambda permissions allowing API gateway to invoke lambda.
resource "aws_lambda_permission" "apigateway_permission" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.inventory_lambda.function_name
  principal     = "apigateway.amazonaws.com"

  # Restrict source to this specific API Gateway ARN for added security
  source_arn = "${aws_apigatewayv2_api.inventory_api.execution_arn}/*/*"
}