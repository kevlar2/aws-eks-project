variable "vpc_cidr" {
  type        = string
  description = "IP range for my vpc"
}

variable "project_name" {
  type        = string
  description = "name of my project"
}

variable "az_count" {
  type        = number
  description = "number of availability zones"
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
  description = "who manages the resource"
  default     = "Terraform"
}

variable "component" {
  type        = string
  description = "component name"
}

variable "cost_center" {
  type        = string
  description = "cost center for billing"
}

variable "application_name" {
  type        = string
  description = "name of the application"
}

variable "service_name" {
  type        = string
  description = "name of the service"
  default     = "vpc"
}