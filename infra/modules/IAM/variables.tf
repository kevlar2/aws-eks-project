variable "eks-cluster-name" {
  type        = string
  description = "Name of the EKS cluster for pod identity associations"
}

variable "route53_zone_id" {
  type        = string
  description = "Route53 hosted zone ID for cert-manager DNS validation"
}

variable "project_name" {
  type        = string
  description = "name of my project"
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

variable "manage_by" {
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
  default     = "iam"
}