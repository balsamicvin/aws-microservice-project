variable "project_name" {
  description = "A unique prefix for all resources"
  type        = string
  default     = "inventory-ms" # Sane default for local testing
}

variable "region" {
  description = "The AWS region to deploy to"
  type        = string
  default     = "us-east-1"
}

# CRITICAL: This variable receives the value from the CI/CD pipeline
# using the -var="image_tag=$IMAGE_TAG" flag in deploy.yml
variable "image_tag" {
  description = "The unique commit SHA or version tag for the Lambda image"
  type        = string
}

variable "lambda_handler_name" {
  description = "The name of the handler function within the code"
  type        = string
  default     = "lambda_handler.lambda_handler"
}