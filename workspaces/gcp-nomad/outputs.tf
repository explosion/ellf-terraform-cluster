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

output "database_ip" {
  value = module.database.database_private_ip
}

output "server_ips" {
  value = module.cluster.server_ips
}

output "server_names" {
  value = module.cluster.server_names
}

output "filestore_ip" {
  value = module.cluster.filestore_ip
}

output "filestore_share_name" {
  value = module.cluster.filestore_share_name
}

output "ingress_ip" {
  value = module.cluster.ingress_ip
}

output "container_registry" {
  value = "${local.gcp_region}-docker.pkg.dev/${var.gcp_project}/${google_artifact_registry_repository.default.repository_id}"
}

output "gossip_key" {
  value     = module.cluster.gossip_key
  sensitive = true
}

output "broker_public_key_pem" {
  value     = module.cluster.broker_public_key_pem
  sensitive = true
}

output "traefik_job_spec" {
  value = module.cluster.traefik_job_spec
}

output "nomad_api_url" {
  value = "http://${module.cluster.server_ips[0]}:4646"
}
