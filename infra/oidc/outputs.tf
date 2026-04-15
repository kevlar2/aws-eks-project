# ------------------------------------------------------------------
# Outputs
# ------------------------------------------------------------------
output "role_arn" {
  description = "IAM Role ARN for GitHub Actions to assume via OIDC"
  value       = module.github_oidc.role_arn
}

output "oidc_provider_arn" {
  description = "GitHub Actions OIDC Provider ARN"
  value       = module.github_oidc.oidc_provider_arn
}
