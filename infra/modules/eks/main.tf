resource "aws_eks_cluster" "eks_cluster" {
  name     = var.cluster_name
  role_arn = var.eks_role_arn
  version  = var.kubernetes_version

  access_config {
    authentication_mode                         = "API" #users are authenticated and gain entrypoint to eks cluster via API
    bootstrap_cluster_creator_admin_permissions = true  #gives user kubernetes admin access, important for working with helm and also kubernetes manifests
  }

  vpc_config {
    subnet_ids              = flatten([var.public_subnet_id, var.private_subnet_id]) #worker nodes in private, control plane in public
    endpoint_public_access  = true                                                   #enables access of kube API server by the internet
    endpoint_private_access = false                                                  #ensures traffic between control plane and worker nodes stays within aws network, very secure

  }

  depends_on = [var.eks_cluster_policy]

  tags = merge(local.common_tags, {
    Name = var.cluster_name
  })
}

data "tls_certificate" "eks" {
  url = aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  url             = aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-oidc-provider"
  })
}

data "aws_iam_policy_document" "csi" {
  statement {
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
    }

    actions = [
      "sts:AssumeRoleWithWebIdentity",
    ]

    condition {
      test     = "StringEquals"
      variable = "${aws_iam_openid_connect_provider.eks.url}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${aws_iam_openid_connect_provider.eks.url}:sub"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }

  }
}

resource "aws_iam_role" "eks_ebs_csi_driver" {
  assume_role_policy = data.aws_iam_policy_document.csi.json
  name               = local.eks_ebs_csi_driver_role_name

  tags = merge(local.common_tags, {
    Name = local.eks_ebs_csi_driver_role_name
  })
}

resource "aws_iam_role_policy_attachment" "amazon_ebs_csi_driver" {
  role       = aws_iam_role.eks_ebs_csi_driver.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}


resource "aws_iam_role" "ebs-csi-role" {
  name = local.ebs_csi_role_name
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "ec2:CreateVolume",
          "ec2:AttachVolume",
          "ec2:DetachVolume",
          "ec2:DeleteVolume",
          "ec2:CreateSnapshot",
          "ec2:DeleteSnapshot",
          "ec2:DescribeVolumes",
          "ec2:DescribeSnapshots",
          "ec2:DescribeInstances",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeVolumeStatus",
          "ec2:DescribeVolumeAttribute",
          "ec2:DescribeSnapshotAttribute",
          "ec2:DescribeInstanceAttribute",
          "ec2:DescribeInstanceCreditSpecifications",
          "ec2:DescribeVolumeTypes",
          "ec2:DescribeVpcAttribute",
          "ec2:DescribeVpcEndpoints",
          "ec2:DescribeVpcs",
          "ec2:ModifyVolume",
          "ec2:ModifyVolumeAttribute",
          "ec2:ModifyInstanceAttribute"
        ],
        "Principal" = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }



    ]
  })

  tags = merge(local.common_tags, {
    Name = local.ebs_csi_role_name
  })

}



resource "aws_iam_role_policy_attachment" "ebs-csi-policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.ebs-csi-role.name
}


resource "aws_launch_template" "eks_worker_nodes" {
  name_prefix   = "${var.project_name}-${var.environment}-eks-workers-"
  instance_type = var.instance_type

  tag_specifications {
    resource_type = "instance"

    tags = merge(local.common_tags, {
      Name = "${var.project_name}-${var.environment}-eks-worker-node"
    })
  }

  tag_specifications {
    resource_type = "volume"

    tags = merge(local.common_tags, {
      Name = "${var.project_name}-${var.environment}-eks-worker-volume"
    })
  }
}



resource "aws_eks_node_group" "eks_worker_node" {
  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_role_arn   = var.eks-node-arn
  node_group_name = var.node-group-name
  subnet_ids      = flatten([var.private_subnet_id])


  scaling_config {
    min_size     = 3
    max_size     = 5
    desired_size = 3
  }

  ami_type = "AL2023_x86_64_STANDARD"

  launch_template {
    id      = aws_launch_template.eks_worker_nodes.id
    version = "$Latest"
  }

  depends_on = [var.eks-node-policy]

  tags = merge(local.common_tags, {
    Name = var.node-group-name
  })
}

#EKS add-ons, these ensure consistent configuration and automated updates
#amazon vpc-CNI, provides networking capabilities to pods
#Core-DNS, provides DNS resolution within cluster
#Kube proxy, maintains network rules on nodes

#First get the latest add on versions
data "aws_eks_addon_version" "vpc-cni" {
  addon_name         = "vpc-cni"
  kubernetes_version = aws_eks_cluster.eks_cluster.version
  most_recent        = true
}

data "aws_eks_addon_version" "core-dns" {
  addon_name         = "coredns"
  kubernetes_version = aws_eks_cluster.eks_cluster.version
  most_recent        = true
}


data "aws_eks_addon_version" "kube-proxy" {
  addon_name         = "kube-proxy"
  kubernetes_version = aws_eks_cluster.eks_cluster.version
  most_recent        = true
}

data "aws_eks_addon_version" "ebs-csi-driver" {
  addon_name         = "aws-ebs-csi-driver"
  kubernetes_version = aws_eks_cluster.eks_cluster.version
  most_recent        = true

}

data "aws_eks_addon_version" "pod-identity-agent" {
  addon_name         = "eks-pod-identity-agent"
  kubernetes_version = aws_eks_cluster.eks_cluster.version
  most_recent        = true

}

data "aws_eks_addon_version" "metrics-server" {
  addon_name         = "metrics-server"
  kubernetes_version = aws_eks_cluster.eks_cluster.version
  most_recent        = true
  
}

resource "aws_eks_addon" "metrics-server" {
  cluster_name  = aws_eks_cluster.eks_cluster.name
  addon_name    = "metrics-server"
  addon_version = data.aws_eks_addon_version.metrics-server.version

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-metrics-server-addon"
  })
}


resource "aws_eks_addon" "vpc-cni" {
  cluster_name  = aws_eks_cluster.eks_cluster.name
  addon_name    = "vpc-cni"
  addon_version = data.aws_eks_addon_version.vpc-cni.version

  resolve_conflicts_on_create = "OVERWRITE" #applies when add-on is being created, overwrites existing one
  resolve_conflicts_on_update = "PRESERVE"  #applies when add-on is updated

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-vpc-cni-addon"
  })
}

resource "aws_eks_addon" "core-dns" {
  cluster_name  = aws_eks_cluster.eks_cluster.name
  addon_name    = "coredns"
  addon_version = data.aws_eks_addon_version.core-dns.version

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-coredns-addon"
  })

  depends_on = [aws_eks_node_group.eks_worker_node]


}

resource "aws_eks_addon" "kube-proxy" {
  cluster_name  = aws_eks_cluster.eks_cluster.name
  addon_name    = "kube-proxy"
  addon_version = data.aws_eks_addon_version.kube-proxy.version

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-kube-proxy-addon"
  })

}

resource "aws_eks_addon" "ebs-csi-driver" {
  cluster_name             = aws_eks_cluster.eks_cluster.name
  addon_name               = "aws-ebs-csi-driver"
  addon_version            = data.aws_eks_addon_version.ebs-csi-driver.version
  service_account_role_arn = aws_iam_role.eks_ebs_csi_driver.arn

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-ebs-csi-addon"
  })

  depends_on = [aws_iam_role_policy_attachment.ebs-csi-policy, aws_eks_node_group.eks_worker_node]

}

resource "aws_eks_addon" "pod-identity-agent" {
  cluster_name  = aws_eks_cluster.eks_cluster.name
  addon_name    = "eks-pod-identity-agent"
  addon_version = data.aws_eks_addon_version.pod-identity-agent.version

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-pod-identity-addon"
  })


}


