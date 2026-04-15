# ------------------------------------------------------------------
# OIDC Identity Provider
# ------------------------------------------------------------------
data "tls_certificate" "github" {
  url = "https://token.actions.githubusercontent.com/.well-known/openid-configuration"
}

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github.certificates[0].sha1_fingerprint]
  tags = merge(local.common_tags, {
    Name = local.oidc_provider_name
  })
}

# ------------------------------------------------------------------
# Trust Policy — allows GitHub Actions from this repo to assume role
# ------------------------------------------------------------------
data "aws_iam_policy_document" "github_actions_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    # Lock down to your specific repo. Use "ref:refs/heads/*" to allow
    # all branches, or "ref:refs/heads/main" for main only.
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${var.github_org}/${var.github_repo}:ref:refs/heads/*",
        "repo:${var.github_org}/${var.github_repo}:pull_request",
      ]
    }
  }
}

# ------------------------------------------------------------------
# IAM Role for GitHub Actions CI/CD
# ------------------------------------------------------------------
resource "aws_iam_role" "github_actions" {
  name               = local.iam_role_name
  assume_role_policy = data.aws_iam_policy_document.github_actions_trust.json
  tags = merge(local.common_tags, {
    Name = local.iam_role_name
  })
}

# ------------------------------------------------------------------
# Permissions — scoped to what the Terraform CI pipeline needs
# ------------------------------------------------------------------
data "aws_iam_policy_document" "github_actions_permissions" {
  # S3: Terraform state backend
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:ListBucket",
      "s3:DeleteObject",
    ]
    resources = [
      "arn:aws:s3:::${var.state_bucket}",
      "arn:aws:s3:::${var.state_bucket}/*",
    ]
  }
  # Read-only for resources Terraform needs to plan/validate against.
  # Adjust these as needed for your actual resource set.
  statement {
    effect = "Allow"
    actions = [
      "ec2:Describe*",
      "eks:Describe*",
      "eks:List*",
      "iam:Get*",
      "iam:List*",
      "elasticloadbalancing:Describe*",
      "acm:Describe*",
      "acm:List*",
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath",
      "sts:GetCallerIdentity",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "github_actions" {
  name   = local.iam_policy_name
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.github_actions_permissions.json
}
