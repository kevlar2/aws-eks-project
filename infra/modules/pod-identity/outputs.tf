output "association_ids" {
  description = "Map of pod identity association IDs keyed by association name"
  value       = { for k, v in aws_eks_pod_identity_association.this : k => v.association_id }
}

output "association_arns" {
  description = "Map of pod identity association ARNs keyed by association name"
  value       = { for k, v in aws_eks_pod_identity_association.this : k => v.association_arn }
}
