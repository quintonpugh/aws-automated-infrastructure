provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "aws-automated-infrastructure"
      ManagedBy   = "Terraform"
      Environment = var.environment
    }
  }
}
