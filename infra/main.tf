module "vpc" {
  source           = "./modules/vpc"
  vpc_cidr         = var.vpc_cidr
  project_name     = var.project_name
  az_count         = var.az_count
  environment      = var.environment
  component        = var.component
  cost_center      = var.cost_center
  application_name = var.application_name
  service_name     = var.service_name
}

module "IAM" {
  source           = "./modules/IAM"
  eks-cluster-name = module.eks.eks-cluster-name
  project_name     = var.project_name
  environment      = var.environment
  component        = var.component
  cost_center      = var.cost_center
  application_name = var.application_name
  service_name     = "iam"
}

module "eks" {
  source             = "./modules/eks"
  cluster_name       = var.cluster_name
  eks_role_arn       = module.IAM.eks-role-arn
  kubernetes_version = var.kubernetes_version
  public_subnet_id   = module.vpc.public_subnet_id
  private_subnet_id  = module.vpc.private_subnet_id
  vpc_id             = module.vpc.vpc_id
  eks_cluster_policy = module.IAM.eks-cluster-policy
  eks-node-arn       = module.IAM.eks-node-arn
  node-group-name    = var.node-group-name
  instance_type      = var.instance_type
  eks-node-policy    = module.IAM.eks-node-policy
  project_name       = var.project_name
  environment        = var.environment
  component          = var.component
  cost_center        = var.cost_center
  application_name   = var.application_name
  service_name       = "eks"
}

