resource "aws_iam_role" "karpenter_node_role" {
  name = "KarpenterNodeRole-${var.cluster_name}"
  path = "/"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = [
          "sts:AssumeRole"
        ]
      }
    ]
  })

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  ]
}

resource "aws_iam_role" "karpenter_controller" {
  name = "karpenter-controller-${var.cluster_name}"
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
          Sid    = "AllowScopedEC2InstanceAccessActions"
          Effect = "Allow"
          Resource = [
            "arn:aws:ec2:us-east-1::image/*",
            "arn:aws:ec2:us-east-1::snapshot/*",
            "arn:aws:ec2:us-east-1:*:security-group/*",
            "arn:aws:ec2:us-east-1:*:subnet/*"
          ]
          Action = [
            "ec2:RunInstances",
            "ec2:CreateFleet"
          ]
        },
        {
          Sid      = "AllowScopedEC2LaunchTemplateAccessActions"
          Effect   = "Allow"
          Resource = "arn:aws:ec2:us-east-1:*:launch-template/*"
          Action = [
            "ec2:RunInstances",
            "ec2:CreateFleet"
          ]
          Condition = {
            "StringEquals" = {
              "aws:ResourceTag/kubernetes.io/cluster/${var.cluster_name}" = "owned"
            },
            "StringLike" = {
              "aws:ResourceTag/karpenter.sh/nodepool" = "*"
            }
          }
        },
        {
          Sid    = "AllowScopedEC2InstanceActionsWithTags"
          Effect = "Allow"
          Resource = [
            "arn:aws:ec2:us-east-1:*:fleet/*",
            "arn:aws:ec2:us-east-1:*:instance/*",
            "arn:aws:ec2:us-east-1:*:volume/*",
            "arn:aws:ec2:us-east-1:*:network-interface/*",
            "arn:aws:ec2:us-east-1:*:launch-template/*",
            "arn:aws:ec2:us-east-1:*:spot-instances-request/*"
          ]
          Action = [
            "ec2:RunInstances",
            "ec2:CreateFleet",
            "ec2:CreateLaunchTemplate"
          ]
          Condition = {
            "StringEquals" = {
              "aws:RequestTag/kubernetes.io/cluster/${var.cluster_name}" = "owned"
            }
            "StringLike" = {
              "aws:RequestTag/karpenter.sh/nodepool" = "*"
            }
          }
        },
        {
          Sid    = "AllowScopedResourceCreationTagging"
          Effect = "Allow"
          Resource = [
            "arn:aws:ec2:us-east-1:*:fleet/*",
            "arn:aws:ec2:us-east-1:*:instance/*",
            "arn:aws:ec2:us-east-1:*:volume/*",
            "arn:aws:ec2:us-east-1:*:network-interface/*",
            "arn:aws:ec2:us-east-1:*:launch-template/*",
            "arn:aws:ec2:us-east-1:*:spot-instances-request/*"
          ]
          Action = "ec2:CreateTags"
          Condition = {
            "StringEquals" = {
              "aws:RequestTag/kubernetes.io/cluster/${var.cluster_name}" = "owned"
              "ec2:CreateAction" = [
                "RunInstances",
                "CreateFleet",
                "CreateLaunchTemplate"
              ]
            }
            "StringLike" = {
              "aws:RequestTag/karpenter.sh/nodepool" = "*"
            }
          }
        },
        {
          Sid      = "AllowScopedResourceTagging"
          Effect   = "Allow"
          Resource = "arn:aws:ec2:us-east-1:*:instance/*"
          Action   = "ec2:CreateTags"
          Condition = {
            "StringEquals" = {
              "aws:ResourceTag/kubernetes.io/cluster/${var.cluster_name}" = "owned"
            }
            "StringLike" = {
              "aws:ResourceTag/karpenter.sh/nodepool" = "*"
            }
            "ForAllValues:StringEquals" = {
              "aws:TagKeys" = [
                "karpenter.sh/nodeclaim",
                "Name"
              ]
            }
          }
        },
        {
          Sid    = "AllowScopedDeletion"
          Effect = "Allow"
          Resource = [
            "arn:aws:ec2:us-east-1:*:instance/*",
            "arn:aws:ec2:us-east-1:*:launch-template/*"
          ]
          Action = [
            "ec2:TerminateInstances",
            "ec2:DeleteLaunchTemplate"
          ]
          Condition = {
            "StringEquals" = {
              "aws:ResourceTag/kubernetes.io/cluster/${var.cluster_name}" = "owned"
            }
            "StringLike" = {
              "aws:ResourceTag/karpenter.sh/nodepool" = "*"
            }
          }
        },
        {
          Sid      = "AllowRegionalReadActions"
          Effect   = "Allow"
          Resource = "*"
          Action = [
            "ec2:DescribeAvailabilityZones",
            "ec2:DescribeImages",
            "ec2:DescribeInstances",
            "ec2:DescribeInstanceTypeOfferings",
            "ec2:DescribeInstanceTypes",
            "ec2:DescribeLaunchTemplates",
            "ec2:DescribeSecurityGroups",
            "ec2:DescribeSpotPriceHistory",
            "ec2:DescribeSubnets"
          ]
          Condition = {
            "StringEquals" = {
              "aws:RequestedRegion" = "us-east-1"
            }
          }
        },
        {
          Sid      = "AllowSSMReadActions"
          Effect   = "Allow"
          Resource = "arn:aws:ssm:us-east-1::parameter/aws/service/*"
          Action   = "ssm:GetParameter"
        },
        {
          Sid      = "AllowPricingReadActions"
          Effect   = "Allow"
          Resource = "*"
          Action   = "pricing:GetProducts"
        },
        {
          Sid      = "AllowInterruptionQueueActions"
          Effect   = "Allow"
          Resource = "${aws_sqs_queue.this.arn}"
          Action = [
            "sqs:DeleteMessage",
            "sqs:GetQueueUrl",
            "sqs:ReceiveMessage"
          ]
        },
        {
          Sid      = "AllowPassingInstanceRole"
          Effect   = "Allow"
          Resource = "${aws_iam_role.karpenter_node_role.arn}"
          Action   = "iam:PassRole"
          Condition = {
            "StringEquals" = {
              "iam:PassedToService" = "ec2.amazonaws.com"
            }
          }
        },
        {
          Sid      = "AllowScopedInstanceProfileCreationActions"
          Effect   = "Allow"
          Resource = "*"
          Action = [
            "iam:CreateInstanceProfile"
          ]
          Condition = {
            "StringEquals" = {
              "aws:RequestTag/kubernetes.io/cluster/${var.cluster_name}" = "owned"
              "aws:RequestTag/topology.kubernetes.io/region"             = "us-east-1"
            }
            "StringLike" = {
              "aws:RequestTag/karpenter.k8s.aws/ec2nodeclass" = "*"
            }
          }
        },
        {
          Sid      = "AllowScopedInstanceProfileTagActions"
          Effect   = "Allow"
          Resource = "*"
          Action = [
            "iam:TagInstanceProfile"
          ]
          Condition = {
            "StringEquals" = {
              "aws:ResourceTag/kubernetes.io/cluster/${var.cluster_name}" = "owned"
              "aws:ResourceTag/topology.kubernetes.io/region"             = "us-east-1"
              "aws:RequestTag/kubernetes.io/cluster/${var.cluster_name}"  = "owned"
              "aws:RequestTag/topology.kubernetes.io/region"              = "us-east-1"
            }
            "StringLike" = {
              "aws:ResourceTag/karpenter.k8s.aws/ec2nodeclass" = "*"
              "aws:RequestTag/karpenter.k8s.aws/ec2nodeclass"  = "*"
            }
          }
        },
        {
          Sid      = "AllowScopedInstanceProfileActions"
          Effect   = "Allow"
          Resource = "*"
          Action = [
            "iam:AddRoleToInstanceProfile",
            "iam:RemoveRoleFromInstanceProfile",
            "iam:DeleteInstanceProfile"
          ]
          Condition = {
            "StringEquals" = {
              "aws:ResourceTag/kubernetes.io/cluster/${var.cluster_name}" = "owned"
              "aws:ResourceTag/topology.kubernetes.io/region"             = "us-east-1"
            }
            "StringLike" = {
              "aws:ResourceTag/karpenter.k8s.aws/ec2nodeclass" = "*"
            }
          }
        },
        {
          Sid      = "AllowInstanceProfileReadActions"
          Effect   = "Allow"
          Resource = "*"
          Action   = "iam:GetInstanceProfile"
        },
        {
          Sid      = "AllowAPIServerEndpointDiscovery"
          Effect   = "Allow"
          Resource = "arn:aws:eks:us-east-1:${data.aws_caller_identity.current.account_id}:cluster/${var.cluster_name}"
          Action   = "eks:DescribeCluster"
        },
        {
          Sid      = "CreateServiceLinkedRole"
          Effect   = "Allow"
          Resource = "*"
          Action   = "iam:CreateServiceLinkedRole"
          Condition = {
            "StringEquals" = {
              "iam:AWSServiceName" = "spot.amazonaws.com"
            }
          }
        }
      ]
    })
  }
}
