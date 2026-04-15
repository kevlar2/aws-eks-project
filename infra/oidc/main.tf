# ==============================================================================
# GitHub Actions OIDC (CI/CD authentication)
# ==============================================================================
module "github_oidc" {
  source       = "../modules/github-oidc"
  github_org   = "kevlar2"
  github_repo  = "aws-eks-project"
  environment  = var.environment
  state_bucket = "2048-eks-project-dev-ko-tf-state"
}

