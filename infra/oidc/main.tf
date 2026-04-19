# ==============================================================================
# GitHub Actions OIDC (CI/CD authentication)
# ==============================================================================
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

module "github_oidc" {
  source       = "../modules/github-oidc"
  github_org   = "kevlar2"
  github_repo  = "aws-eks-project"
  environment  = var.environment
  state_bucket = "2048-eks-project-dev-ko-tf-state"
  ecr_repository_arns = [
    "arn:aws:ecr:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:repository/2048-eks-project-${lower(var.environment)}-2048-game-app",
  ]
  # Grants broad write permissions (resources = ["*"]) for Terraform infra deployment.
  # Acceptable here because:
  #   - OIDC trust policy is scoped to this repo (kevlar2/aws-eks-project) + main branch only
  #   - Single-purpose personal AWS account
  #   - Resource ARN scoping is impractical — Terraform creates resources with dynamic names
  enable_infra_permissions = true
}

