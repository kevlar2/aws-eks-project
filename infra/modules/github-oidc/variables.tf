# ==============================================================================
# GitHub Actions OIDC Provider and CI/CD IAM Role
# ==============================================================================
variable "github_org" {
  description = "GitHub organization or username"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name (without org prefix)"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "Dev"
}

variable "state_bucket" {
  description = "S3 bucket for Terraform state"
  type        = string
}
               