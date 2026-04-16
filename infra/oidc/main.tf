# ==============================================================================
# GitHub Actions OIDC (CI/CD authentication)
# ==============================================================================
module "github_oidc" {
  source       = "../modules/github-oidc"
  github_org   = "kevlar2"
  github_repo  = "aws-eks-project"
  environment  = var.environment
  state_bucket = "2048-eks-project-dev-ko-tf-state"
  ecr_repository_arns = [
    "arn:aws:ecr:eu-west-2:*:repository/2048-eks-project-Dev-2048-game-app",
  ]
}

