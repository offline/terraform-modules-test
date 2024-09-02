terraform {
  required_version = ">= 1.0.0, <2.0.0"
}

provider "helm" {
  kubernetes {
    host                   = module.eks.endpoint
    cluster_ca_certificate = module.eks.certificate

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = [
        "eks",
        "get-token",
        "--cluster-name",
        "${local.cluster_name}",
      ]
    }
  }
}


locals {
  cluster_name = "example"
  kubernetes_public_subnets = [
    {
      zone = "us-east-1a"
      cidr = "172.31.200.0/26"
    },
    {
      zone = "us-east-1b"
      cidr = "172.31.200.64/26"
    }
  ]

  kubernetes_private_subnets = [
    {
      zone = "us-east-1a"
      cidr = "172.31.200.128/26"
    },
    {
      zone = "us-east-1b"
      cidr = "172.31.200.192/26"
    }
  ]
}

data "aws_vpc" "default" {
  default = true
}

module "vpc" {
  source              = "../../modules/kubernetes/vpc"
  cluster_name        = local.cluster_name
  main_route_table_id = data.aws_vpc.default.main_route_table_id
  vpc_id              = data.aws_vpc.default.id
  private_subnets     = local.kubernetes_private_subnets
  public_subnets      = local.kubernetes_public_subnets
}

module "eks" {
  source       = "../../modules/kubernetes/eks"
  cluster_name = local.cluster_name

  private_subnet_ids = module.vpc.private_subnet_ids
  public_subnet_ids  = module.vpc.public_subnet_ids

  access_entries = [
    {
      principal_arn = "arn:aws:iam::024848453929:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_AdministratorAccess_bfbfb777a8671258"
      policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
    }
  ]

  depends_on = [module.vpc]
}

module "external_dns" {
  source       = "../../modules/kubernetes/external-dns"
  cluster_name = local.cluster_name
  domain       = "private.odeeo.link"

  depends_on = [module.eks]
}