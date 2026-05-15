output "database_name" {
  value = module.database.database_name
}

output "database_user" {
  value = module.database.database_user
}

output "database_password" {
  value = module.database.database_password
  sensitive = true
}

output "database_ip" {
  value = module.database.database_private_ip
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

output "filestore_ip" {
  value = module.cluster.filestore_ip
}

output "nfs_pvc_name" {
  value = module.cluster.nfs_pvc_name
}

output "get_credentials_command" {
  value = module.cluster.get_credentials_command
}

output "container_registry" {
  value = "${local.gcp_region}-docker.pkg.dev/${var.gcp_project}/${google_artifact_registry_repository.default.repository_id}"
}

output "ingress_ip" {
  description = "Reserved static IP address for the cluster ingress."
  value       = module.cluster.ingress_ip
}

output "infra_secret_name" {
  description = "Name of the Kubernetes Secret containing infra credentials."
  value       = module.cluster.infra_secret_name
}

output "broker_public_key_pem" {
  description = "PEM-encoded public key for broker registration with PAM."
  value       = module.cluster.broker_public_key_pem
  sensitive   = true
}
