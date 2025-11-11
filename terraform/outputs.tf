# 1. API URL Output
# This is the most critical output, allowing you to access and test your API.
# The CI/CD pipeline references this output at the end to print the URL.
output "api_url" {
  description = "The base URL for the Serverless Inventory API"
  # References the execution ARN of the deployed API Gateway Stage
  value       = aws_apigatewayv2_stage.default.invoke_url
}

# 2. DynamoDB Table Name Output
# Useful for debugging or if a client needs to access the raw database name.
output "dynamodb_table_name" {
  description = "The name of the deployed DynamoDB table"
  value       = aws_dynamodb_table.inventory_table.name
}

# 3. Lambda Function Name Output
# Useful for checking logs in CloudWatch or referencing the function directly.
output "lambda_function_name" {
  description = "The name of the deployed AWS Lambda function"
  value       = aws_lambda_function.inventory_lambda.function_name
}

# 4. ECR Repository URL Output
# Confirms the location where the Docker image was pushed.
output "ecr_repository_url" {
  description = "The URL of the Amazon ECR repository"
  value       = aws_ecr_repository.inventory_repo.repository_url
}