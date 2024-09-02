resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  role_arn = aws_iam_role.clusterrole.arn

  vpc_config {
    endpoint_private_access = true
    endpoint_public_access  = true
    subnet_ids              = concat(var.private_subnet_ids, var.public_subnet_ids)
  }

  access_config {
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = false
  }

  depends_on = [
    aws_iam_role.clusterrole,
  ]
}

resource "aws_eks_node_group" "system" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "system"
  node_role_arn   = aws_iam_role.noderole.arn
  subnet_ids      = var.private_subnet_ids

  scaling_config {
    desired_size = 2
    max_size     = 2
    min_size     = 1
  }

  update_config {
    max_unavailable = 1
  }

  depends_on = [
    aws_iam_role.noderole,
  ]

  taint {
    key    = "CriticalAddonsOnly"
    value  = "true"
    effect = "NO_SCHEDULE"
  }

  labels = {
    "karpenter.sh/controller" = "true"
  }
}

resource "aws_eks_addon" "vpc_cni" {
  cluster_name             = aws_eks_cluster.this.name
  addon_name               = "vpc-cni"
  service_account_role_arn = aws_iam_role.vpc_cni.arn
}

resource "aws_eks_addon" "eks_pod_identity_agent" {
  cluster_name = aws_eks_cluster.this.name
  addon_name   = "eks-pod-identity-agent"
}

resource "aws_eks_addon" "eks_ebs_csi_driver" {
  cluster_name             = aws_eks_cluster.this.name
  addon_name               = "aws-ebs-csi-driver"
  service_account_role_arn = aws_iam_role.ebs_addon.arn
}

resource "aws_eks_addon" "eks_coredns" {
  cluster_name = aws_eks_cluster.this.name
  addon_name   = "coredns"
}

resource "aws_eks_addon" "eks_kube_proxy" {
  cluster_name = aws_eks_cluster.this.name
  addon_name   = "kube-proxy"
}

resource "aws_eks_pod_identity_association" "vpc_cni" {
  cluster_name    = aws_eks_cluster.this.name
  namespace       = "kube-system"
  service_account = "aws-node"
  role_arn        = aws_iam_role.vpc_cni.arn
}

resource "aws_eks_pod_identity_association" "ebs_addon" {
  cluster_name    = aws_eks_cluster.this.name
  namespace       = "kube-system"
  service_account = "ebs-csi-controller-sa"
  role_arn        = aws_iam_role.ebs_addon.arn
}

resource "aws_eks_access_entry" "this" {
  for_each = { for i, v in var.access_entries : i => v }

  cluster_name      = aws_eks_cluster.this.name
  principal_arn     = each.value.principal_arn
  kubernetes_groups = []
  type              = "STANDARD"
}

resource "aws_eks_access_policy_association" "this" {
  for_each = { for i, v in var.access_entries : i => v }

  cluster_name  = aws_eks_cluster.this.name
  policy_arn    = each.value.policy_arn
  principal_arn = each.value.principal_arn

  access_scope {
    type = "cluster"
  }
}
