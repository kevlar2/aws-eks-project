locals {
  eks_cluster_role_name      = "${var.project_name}-${var.environment}-eks-cluster-role"
  node_group_role_name       = "${var.project_name}-${var.environment}-node-group-role"
  cert_manager_policy_name   = "${var.project_name}-${var.environment}-cert-manager-policy"
  cert_manager_pod_role_name = "${var.project_name}-${var.environment}-cert-manager-role"
  external_dns_policy_name   = "${var.project_name}-${var.environment}-external-dns-policy"
  external_dns_pod_role_name = "${var.project_name}-${var.environment}-external-dns-role"

  # Common tags applied to all resources
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = var.manage_by
    Component   = var.component
    CostCenter  = var.cost_center
    Application = var.application_name
    Service     = var.service_name
  }
}