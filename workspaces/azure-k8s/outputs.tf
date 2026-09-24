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
  value = module.database.database_fqdn
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
  value       = "az://${azurerm_storage_container.data.name}"
}

output "cloud_storage_account_url" {
  description = "Blob endpoint of the storage account behind cloud_storage_url; az:// URLs don't name the account."
  value       = azurerm_storage_account.data.primary_blob_endpoint
}

output "workload_identity_client_id" {
  value = module.cluster.workload_identity_client_id
}

output "nfs_pvc_name" {
  value = module.cluster.nfs_pvc_name
}

output "get_credentials_command" {
  value = module.cluster.get_credentials_command
}

output "container_registry" {
  value = azurerm_container_registry.default.login_server
}

output "infra_secret_name" {
  value = module.cluster.infra_secret_name
}

output "broker_public_key_pem" {
  value     = module.cluster.broker_public_key_pem
  sensitive = true
}
