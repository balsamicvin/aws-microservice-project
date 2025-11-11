terraform {
  # Defines the required providers and the minimum version constraint
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # Pinning the version prevents unexpected changes
    }
  }
}

# Configures the AWS provider to use the region defined in variables.tf
provider "aws" {
  region = var.region # Using a variable ensures region is configurable
  # Note: Authentication credentials (keys) are handled automatically by
  # the 'Configure AWS Credentials' step in your deploy.yml, not here.
}