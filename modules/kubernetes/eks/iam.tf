data "aws_iam_policy_document" "pod_identity" {
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

resource "aws_iam_role" "clusterrole" {
  name = "eks-clusterrole-${var.cluster_name}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy",
    # "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  ]
}

resource "aws_iam_role" "vpc_cni" {
  name = "eks-vpc-cni-${var.cluster_name}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sts:AssumeRole",
          "sts:TagSession",
        ],
        Principal = {
          Service = "pods.eks.amazonaws.com"
        }
      }
    ]
  })

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
  ]
}

resource "aws_iam_role" "ebs_addon" {
  name               = "eks-ebs-addon-${var.cluster_name}"
  assume_role_policy = data.aws_iam_policy_document.pod_identity.json

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy",
  ]
}

resource "aws_iam_role" "noderole" {
  name = "eks-noderole-${var.cluster_name}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
  ]
}
