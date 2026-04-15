output "eks-cluster-role" {
  description = "my eks cluster role"
  value       = aws_iam_role.eks-cluster-role.name
}

output "eks-role-arn" {
  description = "arn of eks cluster role"
  value       = aws_iam_role.eks-cluster-role.arn
}

output "eks-node-role" {
  description = "my worker nodes role"
  value       = aws_iam_role.node-group-role.name
}

output "eks-node-arn" {
  description = "arn of worker node"
  value       = aws_iam_role.node-group-role.arn
}

output "cert-manager-pod-identity-role-name" {
  description = "name for role of cert-manager pod identity"
  value       = aws_iam_role.cert-manager-pod-identity-role.name
}

output "cert-policy-arn" {
  description = "arn for cert-manager policy"
  value       = aws_iam_policy.cert-manager-iam-policy.arn
}

output "cert-manager-role-arn" {
  description = "arn of pod identity role for cert-manager"
  value       = aws_iam_role.cert-manager-pod-identity-role.arn
}

output "external-dns-pod-identity-role-name" {
  description = "name of external-dns role"
  value       = aws_iam_role.external-dns-pod-identity-role.name
}

output "external-dns-policy-arn" {
  description = "arn of external-dns policy"
  value       = aws_iam_policy.external-dns-iam-policy.arn
}

output "external-dns-role-arn" {
  description = "arn of external-dns role"
  value       = aws_iam_role.external-dns-pod-identity-role.arn
}

output "eks-cluster-policy" {
  description = "policy required for eks cluster"
  value       = aws_iam_role_policy_attachment.amazon-eks-cluster-policy
}

output "eks-node-policy" {
  description = "policies required for worker nodes"
  value       = aws_iam_role_policy_attachment.amazon-worker-nodes-policy
}





