output "cluster_name" {
  value = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.main.endpoint
}

output "cluster_token" {
  value = data.aws_eks_cluster_auth.main.token
}

output "cluster_ca_data" {
  value = aws_eks_cluster.main.certificate_authority[0].data
}
