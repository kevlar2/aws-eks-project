variable "repository_name" {
  type        = string
  description = "Name of the ECR repository (appended to project-environment prefix)"
}

variable "max_image_count" {
  type        = number
  description = "Maximum number of tagged images to retain in the repository"
  default     = 10
}

variable "project_name" {
  type        = string
  description = "Name of the project"
}

variable "environment" {
  type        = string
  description = "Deployment environment name"
  default     = "Dev"

  validation {
    condition     = contains(["Dev", "Stage", "Prod"], var.environment)
    error_message = "environment must be one of: Dev, Stage, Prod"
  }
}

variable "managed_by" {
  type        = string
  description = "Who manages the resource"
  default     = "Terraform"
}

variable "component" {
  type        = string
  description = "Component name for cost attribution"
}

variable "cost_center" {
  type        = string
  description = "Cost center for billing"
}

variable "application_name" {
  type        = string
  description = "Name of the application"
}

variable "service_name" {
  type        = string
  description = "Name of the service"
  default     = "ecr"
}
