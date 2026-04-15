# ------------------------------------------------------------------
# Outputs
# ------------------------------------------------------------------
output "role_arn" {
  description = "IAM Role ARN for GitHub Actions to assume via OIDC"
  value       = aws_iam_role.github_actions.arn
}

output "oidc_provider_arn" {
  description = "GitHub Actions OIDC Provider ARN"
  value       = aws_iam_openid_connect_provider.github.arn
}
