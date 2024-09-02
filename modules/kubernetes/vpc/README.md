# vpc module


## Overview

This VPC module creates required subnets, NAT gateways and routing tables inside an existing VPC. 
It also sets all required tags specifically to kubernetes in order to allow Karpenter and Load balancers to discover the subnets needed.


## Inputs

- cluster_name - should be unique per AWS account
- main_route_table_id - An ID of the existing VPC main route table. It's used for public subnets in order to grant them access to the internet since main VPC has internet gateway associated with it.
- vpc_id - An VPC ID where all subnets will be created
- private_subnets - a list of objects with the following fields:
    * cidr - a private CIDR in a form of "192.168.1.0/20"
    * zone - avialibility zone name (us-east-1a)
- public_subnets - a list of objects with the following fields:
    * cidr - a private CIDR in a form of "192.168.1.0/20"
    * zone - avialibility zone name (us-east-1a)


## Outputs
- private_subnet_ids - list of private subnet IDs that were created
- public_subnet_ids - list of public subnet IDs that were created