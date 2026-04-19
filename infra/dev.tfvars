# ==============================================================================
# Dev Environment
# ==============================================================================

aws_region         = "eu-west-2"
environment        = "Dev"
project_name       = "2048-eks-project"
cluster_name       = "2048-eks-cluster-dev"
kubernetes_version = "1.34"
node-group-name    = "2048-eks-node-group-dev"
instance_type      = "t3.medium"
vpc_cidr           = "10.0.0.0/16"
az_count           = 2

# Sensitive values provided via:
#   CI:    GitHub secrets (CLUSTER_ADMIN_ARNS, ROUTE53_ZONE_ID)
#   Local: terraform.tfvars override or -var flag
# - route53_zone_id
# - cluster_admin_arns
