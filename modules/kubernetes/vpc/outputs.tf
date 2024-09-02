output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = aws_subnet.kubernetes_private[*].id
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = aws_subnet.kubernetes_public[*].id
}
