output "endpoint" {
  description = "Kubernetes endpoint"
  value       = aws_eks_cluster.this.endpoint
}

output "certificate" {
  description = "Kubernetes cluster certificate"
  value       = base64decode(aws_eks_cluster.this.certificate_authority[0].data)
}

output "cluster_security_group_id" {
  description = "Kubernetes primary group id"
  value       = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}
