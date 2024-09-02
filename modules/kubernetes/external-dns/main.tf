resource "aws_route53_zone" "this" {
  name = var.domain
}

resource "aws_eks_pod_identity_association" "this" {
  cluster_name    = var.cluster_name
  namespace       = "kube-system"
  service_account = "external-dns-controller"
  role_arn        = aws_iam_role.this.arn
}

resource "helm_release" "this" {
  name       = "external-dns-controller"
  repository = "oci://registry-1.docker.io/bitnamicharts"
  version    = "8.3.3"
  chart      = "external-dns"
  namespace  = "kube-system"

  set {
    name  = "provider"
    value = "aws"
  }

  set {
    name  = "aws.region"
    value = "us-east-1"
  }

  set {
    name  = "txtOwnerId"
    value = aws_route53_zone.this.zone_id
  }

  set {
    name  = "domainFilters[0]"
    value = var.domain
  }

  set {
    name  = "serviceAccount.name"
    value = "external-dns-controller"
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "policy"
    value = "sync"
  }

  set {
    name  = "tolerations[0].key"
    value = "CriticalAddonsOnly"
  }

  set {
    name  = "tolerations[0].operator"
    value = "Exists"
  }
}
