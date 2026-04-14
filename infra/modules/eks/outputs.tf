output "eks-cluster-name" {
  description = "name of eks cluster"
  value       = aws_eks_cluster.eks_cluster.name
}

output "vpc-cni-version" {
  description = "version of addon for vpc-cni"
  value       = data.aws_eks_addon_version.vpc-cni.version
}

output "core-dns-version" {
  description = "version of addon for core-dns"
  value       = data.aws_eks_addon_version.core-dns.version
}

output "kube-proxy-version" {
  description = "version of addon for kube-proxy"
  value       = data.aws_eks_addon_version.kube-proxy.version
}

output "ebs-csi-version" {
  description = "version of addon for ebs-csi"
  value       = data.aws_eks_addon_version.ebs-csi-driver.version
}

output "pod-identity-agent-version" {
  description = "version of addon for pod identity agent"
  value       = data.aws_eks_addon_version.pod-identity-agent.version
}