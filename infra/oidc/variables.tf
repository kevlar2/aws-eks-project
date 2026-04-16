variable "aws_region" {
  type        = string
  description = "AWS region for resource deployment"
  default     = "eu-west-2"
}

variable "environment" {
  type        = string
  description = "Deployment environment"
  default     = "Dev"

  validation {
    condition     = contains(["Dev", "Stage", "Prod"], var.environment)
    error_message = "environment must be one of: Dev, Stage, Prod"
  }
}
