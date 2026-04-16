locals {
  vpc_name                = lower("${var.project_name}-${var.environment}-vpc")
  igw_name                = lower("${var.project_name}-${var.environment}-igw")
  ngw_name                = lower("${var.project_name}-${var.environment}-ngw")
  public_route_table_name = lower("${var.project_name}-${var.environment}-public-route-table")
  public_subnet_names     = [for i in range(var.az_count) : lower("${var.project_name}-${var.environment}-public-subnet-${i + 1}")]
  private_subnet_names    = [for i in range(var.az_count) : lower("${var.project_name}-${var.environment}-private-subnet-${i + 1}")]
  route_table_names       = [for i in range(var.az_count) : lower("${var.project_name}-${var.environment}-route-table-${i + 1}")]
  elastic_ip_names        = [for i in range(var.az_count) : lower("${var.project_name}-${var.environment}-eip-${i + 1}")]
  security_group_name     = lower("${var.project_name}-${var.environment}-sg")

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
