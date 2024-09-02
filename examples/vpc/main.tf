terraform {
  required_version = ">= 1.0.0, <2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.16"
    }
  }
}

locals {
  kubernetes_public_subnets = [
    {
      zone = "us-east-1a"
      cidr = "172.31.96.0/20"
    },
    {
      zone = "us-east-1b"
      cidr = "172.31.112.0/20"
    }
  ]

  kubernetes_private_subnets = [
    {
      zone = "us-east-1a"
      cidr = "172.31.128.0/20"
    },
    {
      zone = "us-east-1b"
      cidr = "172.31.144.0/20"
    }
  ]
}

data "aws_vpc" "default" {
  default = true
}

module "vpc" {
  source              = "../../modules/kubernetes/vpc"
  cluster_name        = "adserver"
  main_route_table_id = data.aws_vpc.default.main_route_table_id
  vpc_id              = data.aws_vpc.default.id
  private_subnets     = local.kubernetes_private_subnets
  public_subnets      = local.kubernetes_public_subnets
}

output "private_subnet_ids" {
  value = module.vpc.private_subnet_ids
}

output "public_subnet_ids" {
  value = module.vpc.public_subnet_ids
}
