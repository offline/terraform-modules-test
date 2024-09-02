data "aws_caller_identity" "current" {}


resource "aws_eks_access_entry" "this" {
  cluster_name  = var.cluster_name
  principal_arn = aws_iam_role.karpenter_node_role.arn
  type          = "EC2_LINUX"
}

resource "aws_sqs_queue" "this" {
  name                      = "eks-${var.cluster_name}"
  message_retention_seconds = 300
  sqs_managed_sse_enabled   = true
}

resource "aws_sqs_queue_policy" "this" {
  queue_url = aws_sqs_queue.this.id

  policy = jsonencode({
    Version = "2008-10-17"
    Id      = "EC2InterruptionPolicy"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = [
            "events.amazonaws.com",
            "sqs.amazonaws.com"
          ]
        }
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.this.arn
      }
    ]
  })
}

resource "aws_cloudwatch_event_rule" "scheduled_change_rule" {
  event_pattern = jsonencode({
    source = [
      "aws.health"
    ]
    detail-type = [
      "AWS Health Event"
    ]
  })
}

resource "aws_cloudwatch_event_target" "scheduled_change_rule" {
  target_id = "k8s-scheduled-change-rule-${var.cluster_name}"
  rule      = aws_cloudwatch_event_rule.scheduled_change_rule.name
  arn       = aws_sqs_queue.this.arn
}

resource "aws_cloudwatch_event_rule" "spot_interruption_rule" {
  event_pattern = jsonencode({
    source = [
      "aws.ec2"
    ]
    detail-type = [
      "EC2 Spot Instance Interruption Warning"
    ]
  })
}

resource "aws_cloudwatch_event_target" "spot_interruption_rule" {
  target_id = "k8s-spot-interruption-rule-${var.cluster_name}"
  rule      = aws_cloudwatch_event_rule.spot_interruption_rule.name
  arn       = aws_sqs_queue.this.arn
}

resource "aws_cloudwatch_event_rule" "rebalance_rule" {
  event_pattern = jsonencode({
    source = [
      "aws.ec2"
    ]
    detail-type = [
      "EC2 Instance Rebalance Recommendation"
    ]
  })
}

resource "aws_cloudwatch_event_target" "rebalance_rule" {
  target_id = "k8s-rebalance-rule-${var.cluster_name}"
  rule      = aws_cloudwatch_event_rule.rebalance_rule.name
  arn       = aws_sqs_queue.this.arn
}

resource "aws_cloudwatch_event_rule" "instance_state_change_rule" {
  event_pattern = jsonencode({
    source = [
      "aws.ec2"
    ]
    detail-type = [
      "EC2 Instance State-change Notification"
    ]
  })
}

resource "aws_cloudwatch_event_target" "instance_state_change_rule" {
  target_id = "k8s-state-change-rule-${var.cluster_name}"
  rule      = aws_cloudwatch_event_rule.instance_state_change_rule.name
  arn       = aws_sqs_queue.this.arn
}

resource "aws_eks_pod_identity_association" "esk_karpenter" {
  cluster_name    = var.cluster_name
  namespace       = "karpenter"
  service_account = "karpenter"
  role_arn        = aws_iam_role.karpenter_controller.arn
}


resource "helm_release" "karpenter" {
  name       = "karpenter"
  repository = "oci://public.ecr.aws/karpenter"
  chart      = "karpenter"
  version    = "0.37.0"
  namespace  = "karpenter"

  set {
    name  = "serviceAccount.name"
    value = "karpenter"
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "settings.clusterName"
    value = var.cluster_name
  }

  set {
    name  = "settings.interruptionQueue"
    value = aws_sqs_queue.this.name
  }

  set {
    name  = "tolerations[0].key"
    value = "CriticalAddonsOnly"
  }

  set {
    name  = "tolerations[0].operator"
    value = "Exists"
  }

  depends_on = [kubernetes_namespace.karpenter]
}

resource "kubernetes_namespace" "karpenter" {
  metadata {
    name = "karpenter"
  }
}

resource "kubectl_manifest" "karpenter_node_class" {
  yaml_body = <<-YAML
    apiVersion: karpenter.k8s.aws/v1beta1
    kind: EC2NodeClass
    metadata:
      name: default
    spec:
      amiFamily: AL2023
      role: "KarpenterNodeRole-${var.cluster_name}"
      subnetSelectorTerms:
        - tags:
            karpenter.sh/discovery: "${var.cluster_name}"
      securityGroupSelectorTerms:
        - tags:
            karpenter.sh/discovery: "${var.cluster_name}" 
  YAML

  depends_on = [
    helm_release.karpenter
  ]
}

resource "kubectl_manifest" "karpenter_node_pool" {
  yaml_body = <<-YAML
    apiVersion: karpenter.sh/v1beta1
    kind: NodePool
    metadata:
      name: default
    spec:
      template:
        spec:
          requirements:
            - key: karpenter.sh/capacity-type
              operator: In
              values: ["spot", "on-demand"]
            - key: karpenter.k8s.aws/instance-family
              operator: In
              values:
              - c7g
              - c6g
              - c5g
              - x2gd
              - c7i
              - c7a
              - c6i
              - c6a
              - c5
            - key: kubernetes.io/arch
              operator: In
              values:
              - amd64
              - arm64
            - key: karpenter.k8s.aws/instance-cpu
              operator: Gt
              values: ["1"]

          nodeClassRef:
            apiVersion: karpenter.k8s.aws/v1
            kind: EC2NodeClass
            name: default
      limits:
        cpu: 1000
      disruption:
        consolidationPolicy: WhenUnderutilized
        expireAfter: 720h # 30 * 24h = 720h
  YAML

  depends_on = [
    kubectl_manifest.karpenter_node_class
  ]
}

resource "aws_ec2_tag" "cluster_primary_security_group" {
  resource_id = var.cluster_security_group_id
  key         = "karpenter.sh/discovery"
  value       = var.cluster_name
}
