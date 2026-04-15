variable "cluster_name" {
  type        = string
  description = "name of my eks cluster"
}

variable "eks_role_arn" {
  type        = string
  description = "ARN of the IAM role for the EKS cluster"
}

variable "kubernetes_version" {
  type        = string
  description = "version of kubernetes"
}

variable "public_subnet_id" {
  type        = list(string)
  description = "List of public subnet IDs for the EKS cluster"
}

variable "private_subnet_id" {
  type        = list(string)
  description = "List of private subnet IDs for the EKS worker nodes"
}

variable "vpc_id" {
  type        = string
  description = "ID of the VPC where the EKS cluster is deployed"
}

variable "eks_cluster_policy" {
  type        = any
  description = "EKS cluster IAM policy attachment (used for depends_on ordering)"
}

variable "eks-node-arn" {
  type        = string
  description = "ARN of the IAM role for EKS worker nodes"
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
  type        = any
  description = "EKS worker node IAM policy attachments (used for depends_on ordering)"
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
