variable "aws_region" {
  type        = string
  description = "AWS region for resource deployment"
  default     = "eu-west-2"
}

variable "vpc_cidr" {
  type        = string
  description = "IP range for my vpc"
  default     = "10.0.0.0/16"
}

variable "project_name" {
  type        = string
  description = "name of my project"
  default     = "2048-eks-project"
}

variable "az_count" {
  type        = number
  description = "number of availability zones"
  default     = 2
}

variable "cluster_name" {
  type        = string
  description = "name of eks cluster"
  default     = "2048-eks-cluster"
}

variable "kubernetes_version" {
  type        = string
  description = "version of kubernetes"
  default     = "1.34"
}

variable "node-group-name" {
  type        = string
  description = "name of node group"
  default     = "2048-eks-node-group"
}

variable "instance_type" {
  description = "EC2 instance type for the EKS worker nodes"
  type        = string
  default     = "t3.medium"
}

variable "route53_zone_id" {
  type        = string
  description = "Route53 hosted zone ID for cert-manager DNS validation"
  default     = "Z008157839VKLC5BD1MTT"
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

variable "component" {
  type        = string
  description = "Component name for cost attribution"
  default     = "networking"
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
  default     = "networking"
}

variable "cluster_admin_arns" {
  type        = list(string)
  description = "IAM principal ARNs to grant EKS cluster admin access"
  default     = []
}

