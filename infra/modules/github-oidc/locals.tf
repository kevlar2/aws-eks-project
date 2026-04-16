locals {
  oidc_provider_name = lower("${var.github_repo}-${var.environment}-github-oidc")
  iam_role_name      = lower("${var.github_repo}-${var.environment}-github-actions-role")
  iam_policy_name    = lower("${var.github_repo}-${var.environment}-github-actions-policy")

  common_tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
    Component   = "ci-cd"
    Repository  = "${var.github_org}/${var.github_repo}"
  }
}
