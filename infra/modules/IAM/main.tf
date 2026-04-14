#IAM role for eks cluster
resource "aws_iam_role" "eks-cluster-role" {
  name = local.eks_cluster_role_name
  assume_role_policy = jsonencode({

    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "eks.amazonaws.com"
        }
      },
    ]
    }
  )

  tags = merge(local.common_tags, {
    Name = local.eks_cluster_role_name
  })
}

#to provide the permissions to the eks cluster we need to attach the assumed role to the eks cluster policy
resource "aws_iam_role_policy_attachment" "amazon-eks-cluster-policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks-cluster-role.name
}

#IAM role for worker nodes
resource "aws_iam_role" "node-group-role" {
  name = local.node_group_role_name
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  tags = merge(local.common_tags, {
    Name = local.node_group_role_name
  })

}

#Attach required policies to worker node role for the neccessary permissions
resource "aws_iam_role_policy_attachment" "amazon-worker-nodes-policy" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",          #connects nodes to cluster
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",               #provides CNI the permissions it needs to assign IP addresses to pods allowing them to communicate and with the VPC network, basically needed for networking. 
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly", #allows node to pull images from ECR repo
    "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"

  ])

  policy_arn = each.value
  role       = aws_iam_role.node-group-role.name
}

#pod identity gives permissions to pods in cluster to interact with other aws services
#particularly pods where k8s applications such as cert-manager and external-dns live
#This is because cert-manager and external-dns have to call AWS APIs to interact with services such as route-53
#below is the trust policy required for eks pod identity

data "aws_iam_policy_document" "cert-manager" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }

    actions = [
      "sts:AssumeRole",
      "sts:TagSession"
    ]
  }
}

#cert-manager IAM policy 
resource "aws_iam_policy" "cert-manager-iam-policy" {
  name = local.cert_manager_policy_name
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : "route53:GetChange",
        "Resource" : "arn:aws:route53:::change/*"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "route53:ChangeResourceRecordSets",
          "route53:ListResourceRecordSets"
        ],
        "Resource" : "arn:aws:route53:::hostedzone/Z0075379YVJ2NJZFXYU",
        "Condition" : {
          "ForAllValues:StringEquals" : {
            "route53:ChangeResourceRecordSetsRecordTypes" : ["TXT"]
          }
        }
      },
      {
        "Effect" : "Allow",
        "Action" : "route53:ListHostedZonesByName",
        "Resource" : "*"
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = local.cert_manager_policy_name
  })
}

#IAM role for pod identity with trust policy
resource "aws_iam_role" "cert-manager-pod-identity-role" {
  name               = local.cert_manager_pod_role_name
  assume_role_policy = data.aws_iam_policy_document.cert-manager.json

  tags = merge(local.common_tags, {
    Name = local.cert_manager_pod_role_name
  })
}

#attach policy to IAM role
resource "aws_iam_role_policy_attachment" "cert-manager-policy-attachment" {
  role       = aws_iam_role.cert-manager-pod-identity-role.name
  policy_arn = aws_iam_policy.cert-manager-iam-policy.arn
}

#associate pod identity with IAM role
resource "aws_eks_pod_identity_association" "cert-manager" {
  cluster_name    = var.eks-cluster-name
  namespace       = "cert-manager"
  service_account = "cert-manager"
  role_arn        = aws_iam_role.cert-manager-pod-identity-role.arn
  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-cert-manager-pod-identity-association"
  })
}

#External-dns IAM policy
data "aws_iam_policy_document" "external-dns" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }

    actions = [
      "sts:AssumeRole",
      "sts:TagSession"
    ]
  }
}

resource "aws_iam_policy" "external-dns-iam-policy" {
  name = local.external_dns_policy_name
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "route53:ChangeResourceRecordSets"
        ],
        "Resource" : [
          "arn:aws:route53:::hostedzone/*"
        ]
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "route53:ListHostedZones",
          "route53:ListResourceRecordSets"
        ],
        "Resource" : [
          "*"
        ]
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = local.external_dns_policy_name
  })
}

#IAM role for pod identity with trust policy
resource "aws_iam_role" "external-dns-pod-identity-role" {
  name               = local.external_dns_pod_role_name
  assume_role_policy = data.aws_iam_policy_document.external-dns.json

  tags = merge(local.common_tags, {
    Name = local.external_dns_pod_role_name
  })
}

#attach policy to IAM role
resource "aws_iam_role_policy_attachment" "external-dns-policy-attachment" {
  role       = aws_iam_role.external-dns-pod-identity-role.name
  policy_arn = aws_iam_policy.external-dns-iam-policy.arn
}

#associate pod identity with IAM role
resource "aws_eks_pod_identity_association" "external-dns" {
  cluster_name    = var.eks-cluster-name
  namespace       = "external-dns"
  service_account = "external-dns"
  role_arn        = aws_iam_role.external-dns-pod-identity-role.arn
  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-external-dns-pod-identity-association"
  })
}





















