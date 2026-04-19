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
  eks-cluster-name = var.cluster_name
  route53_zone_id  = var.route53_zone_id
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

module "ecr" {
  source           = "./modules/ecr"
  repository_name  = "2048-game-app"
  project_name     = var.project_name
  environment      = var.environment
  component        = var.component
  cost_center      = var.cost_center
  application_name = var.application_name
  service_name     = "ecr"
}

# ==============================================================================
# EKS Access Entries — grant cluster admin to specified IAM principals
# ==============================================================================
resource "aws_eks_access_entry" "cluster_admins" {
  for_each      = toset(var.cluster_admin_arns)
  cluster_name  = module.eks.eks-cluster-name
  principal_arn = each.value
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "cluster_admins" {
  for_each      = toset(var.cluster_admin_arns)
  cluster_name  = module.eks.eks-cluster-name
  principal_arn = each.value
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}

module "pod_identity" {
  source       = "./modules/pod-identity"
  cluster_name = module.eks.eks-cluster-name

  associations = {
    cert-manager = {
      namespace       = "cert-manager"
      service_account = "cert-manager"
      role_arn        = module.IAM.cert-manager-role-arn
    }
    external-dns = {
      namespace       = "external-dns"
      service_account = "external-dns"
      role_arn        = module.IAM.external-dns-role-arn
    }
  }

  project_name     = var.project_name
  environment      = var.environment
  component        = var.component
  cost_center      = var.cost_center
  application_name = var.application_name
  service_name     = "pod-identity"
}

