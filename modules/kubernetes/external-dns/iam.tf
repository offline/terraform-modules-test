resource "aws_iam_role" "this" {
  name = "k8s-external-dns-controller-${var.cluster_name}"
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
    }]
  })

  inline_policy {
    name = "policy"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Sid      = "ChangeResourceRecordSets"
          Effect   = "Allow"
          Resource = "arn:aws:route53:::hostedzone/${aws_route53_zone.this.zone_id}"
          Action = [
            "route53:ChangeResourceRecordSets",
          ]
        },
        {
          Sid      = "ListHostedZones"
          Effect   = "Allow"
          Resource = "*"
          Action = [
            "route53:ListHostedZones",
            "route53:ListResourceRecordSets"
          ]
        },
      ]
    })
  }
}
