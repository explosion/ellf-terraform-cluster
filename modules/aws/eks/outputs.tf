output "cluster_name" {
  value = aws_eks_cluster.primary.name
}

output "cluster_endpoint" {
  value     = aws_eks_cluster.primary.endpoint
  sensitive = true
}

output "cluster_ca_certificate" {
  value     = aws_eks_cluster.primary.certificate_authority[0].data
  sensitive = true
}

output "efs_id" {
  value = aws_efs_file_system.nfs.id
}

output "nfs_pvc_name" {
  value = kubernetes_persistent_volume_claim_v1.efs.metadata[0].name
}

output "node_role_arn" {
  value = aws_iam_role.eks_nodes.arn
}

output "node_security_group_id" {
  value = aws_security_group.eks_nodes.id
}

output "get_credentials_command" {
  value = "aws eks update-kubeconfig --region ${var.aws_region} --name ${aws_eks_cluster.primary.name}"
}

output "infra_secret_name" {
  value = kubernetes_secret_v1.infra.metadata[0].name
}

output "broker_public_key_pem" {
  value     = tls_private_key.broker.public_key_pem
  sensitive = true
}
