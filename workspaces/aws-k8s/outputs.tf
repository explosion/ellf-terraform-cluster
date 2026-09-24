output "database_name" {
  value = module.database.database_name
}

output "database_user" {
  value = module.database.database_user
}

output "database_password" {
  value     = module.database.database_password
  sensitive = true
}

# On AWS this is the RDS DNS endpoint, not a literal IP — RDS never exposes
# a stable address. Consumers that need a CIDR (the broker NetworkPolicy's
# postgres egress rule) must use database_egress_cidr instead of appending
# /32 to this value.
output "database_ip" {
  value = module.database.database_address
}

# CIDR covering the database for network-policy egress rules. The RDS
# instance lives in the VPC's private subnets and its endpoint IP can change
# on failover or maintenance, so the whole VPC range (scoped to port 5432 by
# the consumer) is the stable answer.
output "database_egress_cidr" {
  value = var.vpc_cidr
}

output "cluster_name" {
  value = module.cluster.cluster_name
}

output "cluster_endpoint" {
  value     = module.cluster.cluster_endpoint
  sensitive = true
}

output "cluster_ca_certificate" {
  value     = module.cluster.cluster_ca_certificate
  sensitive = true
}

output "cloud_storage_url" {
  description = "The cluster's object storage, as the URL the broker serves as {__cloud_storage__}."
  value       = "s3://${aws_s3_bucket.data.id}"
}

output "efs_id" {
  value = module.cluster.efs_id
}

output "nfs_pvc_name" {
  value = module.cluster.nfs_pvc_name
}

output "get_credentials_command" {
  value = module.cluster.get_credentials_command
}

output "container_registry" {
  value = aws_ecr_repository.default.repository_url
}

output "infra_secret_name" {
  value = module.cluster.infra_secret_name
}

output "broker_public_key_pem" {
  value     = module.cluster.broker_public_key_pem
  sensitive = true
}
