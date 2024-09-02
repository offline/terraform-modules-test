variable "cluster_name" {
  type = string
}

variable "main_route_table_id" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnets" {
  type = list(object({
    cidr = string
    zone = string
  }))
}

variable "public_subnets" {
  type = list(object({
    cidr = string
    zone = string
  }))
}
