variable "project_name" {
  type        = string
  description = "Name of the project"
  default     = "2048-eks-project"
}

variable "environment" {
  type        = string
  description = "Deployment environment"
  default     = "dev"

  validation {
    condition     = contains(["dev", "stage", "prod"], var.environment)
    error_message = "environment must be one of: dev, stage, prod"
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
  default     = "bootstrap"
}

variable "cost_center" {
  type        = string
  description = "Cost center for billing"
  default     = "platform"
}

variable "application_name" {
  type        = string
  description = "Name of the application"
  default     = "eks-platform"
}

variable "service_name" {
  type        = string
  description = "Service name for cost attribution"
  default     = "s3"
}
