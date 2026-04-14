variable "cluster_name" {
  type        = string
  description = "name of my eks cluster"
}

variable "eks_role_arn" {
}

variable "kubernetes_version" {
  type        = string
  description = "version of kubernetes"
}

variable "public_subnet_id" {
}

variable "private_subnet_id" {
}

variable "vpc_id" {
}

variable "eks_cluster_policy" {
}

variable "eks-node-arn" {
}

variable "node-group-name" {
  type        = string
  description = "name of node group"
}

variable "instance_type" {
  description = "EC2 instance type for the EKS worker nodes"
  type        = string
}

variable "eks-node-policy" {
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
  default     = "eks"
}





