output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnet_id" {
  value = module.vpc.public_subnet_id
}

output "private_subnet_id" {
  value = module.vpc.private_subnet_id
}

output "security_group_id" {
  value = module.vpc.security_group_id
}

output "eks-role-arn" {
  value = module.IAM.eks-role-arn
}

output "eks-node-arn" {
  value = module.IAM.eks-node-arn
}

output "cert-manager-role-arn" {
  value = module.IAM.cert-manager-role-arn
}

output "external-dns-role-arn" {
  value = module.IAM.external-dns-role-arn
}

output "eks-cluster-name" {
  value = module.eks.eks-cluster-name
}

output "kubeconfig_update_command" {
  description = "Convenience command to update local kubeconfig using awscli"
  value       = module.eks.kubeconfig_update_command
}

output "ecr_repository_url" {
  description = "Full URL of the ECR repository for docker push/pull"
  value       = module.ecr.repository_url
}

output "ecr_repository_arn" {
  description = "ARN of the ECR repository"
  value       = module.ecr.repository_arn
}







