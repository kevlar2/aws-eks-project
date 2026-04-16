locals {
  eks_ebs_csi_driver_role_name = lower("${var.project_name}-${var.environment}-eks-ebs-csi-driver-role")

  # Common tags applied to all resources
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = var.managed_by
    Component   = var.component
    CostCenter  = var.cost_center
    Application = var.application_name
    Service     = var.service_name
  }
}