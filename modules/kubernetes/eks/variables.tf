variable "cluster_name" {
  type = string
}

variable "access_entries" {
  description = "List of access entries with principal ARN and policy ARN."
  type = list(object({
    principal_arn = string
    policy_arn    = string
  }))
  default = []
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs"
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs"
  type        = list(string)
}
