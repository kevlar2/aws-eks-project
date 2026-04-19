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

  # ECR: authentication token (must be resource "*")
  dynamic "statement" {
    for_each = length(var.ecr_repository_arns) > 0 ? [1] : []
    content {
      effect    = "Allow"
      actions   = ["ecr:GetAuthorizationToken"]
      resources = ["*"]
    }
  }

  # ECR: push and pull images (scoped to specific repositories)
  dynamic "statement" {
    for_each = length(var.ecr_repository_arns) > 0 ? [1] : []
    content {
      effect = "Allow"
      actions = [
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload",
        "ecr:DescribeRepositories",
        "ecr:ListImages",
      ]
      resources = var.ecr_repository_arns
    }
  }

  # Infrastructure deployment permissions (VPC, EKS, IAM, EC2, ECR)
  dynamic "statement" {
    for_each = var.enable_infra_permissions ? [1] : []
    content {
      effect = "Allow"
      actions = [
        # VPC & Networking
        "ec2:CreateVpc", "ec2:DeleteVpc", "ec2:ModifyVpcAttribute",
        "ec2:CreateSubnet", "ec2:DeleteSubnet",
        "ec2:CreateInternetGateway", "ec2:DeleteInternetGateway",
        "ec2:AttachInternetGateway", "ec2:DetachInternetGateway",
        "ec2:CreateNatGateway", "ec2:DeleteNatGateway",
        "ec2:AllocateAddress", "ec2:ReleaseAddress", "ec2:DisassociateAddress",
        "ec2:CreateRouteTable", "ec2:DeleteRouteTable",
        "ec2:CreateRoute", "ec2:DeleteRoute",
        "ec2:AssociateRouteTable", "ec2:DisassociateRouteTable",
        "ec2:CreateSecurityGroup", "ec2:DeleteSecurityGroup",
        "ec2:AuthorizeSecurityGroupIngress", "ec2:RevokeSecurityGroupIngress",
        "ec2:AuthorizeSecurityGroupEgress", "ec2:RevokeSecurityGroupEgress",
        "ec2:CreateTags", "ec2:DeleteTags",
        "ec2:CreateLaunchTemplate", "ec2:DeleteLaunchTemplate",
        "ec2:ModifySubnetAttribute",

        # EKS
        "eks:CreateCluster", "eks:DeleteCluster", "eks:UpdateClusterConfig",
        "eks:UpdateClusterVersion", "eks:TagResource", "eks:UntagResource",
        "eks:CreateNodegroup", "eks:DeleteNodegroup", "eks:UpdateNodegroupConfig",
        "eks:UpdateNodegroupVersion",
        "eks:CreateAddon", "eks:DeleteAddon", "eks:UpdateAddon",
        "eks:AssociateAccessPolicy", "eks:DisassociateAccessPolicy",
        "eks:CreateAccessEntry", "eks:DeleteAccessEntry",
        "eks:CreatePodIdentityAssociation", "eks:DeletePodIdentityAssociation",
        "eks:DescribePodIdentityAssociation", "eks:ListPodIdentityAssociations",
        "eks:AccessKubernetesApi",

        # IAM
        "iam:CreateRole", "iam:DeleteRole", "iam:UpdateRole",
        "iam:AttachRolePolicy", "iam:DetachRolePolicy",
        "iam:PutRolePolicy", "iam:DeleteRolePolicy",
        "iam:CreatePolicy", "iam:DeletePolicy",
        "iam:CreatePolicyVersion", "iam:DeletePolicyVersion",
        "iam:TagRole", "iam:UntagRole", "iam:TagPolicy", "iam:UntagPolicy",
        "iam:PassRole",
        "iam:CreateOpenIDConnectProvider", "iam:DeleteOpenIDConnectProvider",
        "iam:UpdateOpenIDConnectProviderThumbprint",
        "iam:TagOpenIDConnectProvider", "iam:UntagOpenIDConnectProvider",
        "iam:CreateServiceLinkedRole",

        # ECR (create/manage repositories)
        "ecr:CreateRepository", "ecr:DeleteRepository",
        "ecr:PutLifecyclePolicy", "ecr:DeleteLifecyclePolicy",
        "ecr:GetLifecyclePolicy", "ecr:GetLifecyclePolicyPreview",
        "ecr:SetRepositoryPolicy", "ecr:DeleteRepositoryPolicy",
        "ecr:GetRepositoryPolicy",
        "ecr:TagResource", "ecr:UntagResource",
        "ecr:PutImageScanningConfiguration",
        "ecr:PutImageTagMutability",

        # KMS (EKS envelope encryption)
        "kms:CreateKey", "kms:DescribeKey", "kms:CreateAlias",
        "kms:CreateGrant", "kms:ListGrants",

        # CloudWatch Logs (EKS control plane logging)
        "logs:CreateLogGroup", "logs:DeleteLogGroup",
        "logs:PutRetentionPolicy", "logs:TagLogGroup",
        "logs:DescribeLogGroups",
      ]
      resources = ["*"]
    }
  }
}

resource "aws_iam_role_policy" "github_actions" {
  name   = local.iam_policy_name
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.github_actions_permissions.json
}
