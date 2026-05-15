output "cluster_name" {
  value = azurerm_kubernetes_cluster.primary.name
}

output "cluster_endpoint" {
  value     = azurerm_kubernetes_cluster.primary.kube_config[0].host
  sensitive = true
}

output "cluster_ca_certificate" {
  value     = azurerm_kubernetes_cluster.primary.kube_config[0].cluster_ca_certificate
  sensitive = true
}

output "kubelet_identity_object_id" {
  value = azurerm_kubernetes_cluster.primary.kubelet_identity[0].object_id
}

output "node_resource_group" {
  value = azurerm_kubernetes_cluster.primary.node_resource_group
}

output "nfs_pvc_name" {
  value = kubernetes_persistent_volume_claim_v1.nfs.metadata[0].name
}

output "get_credentials_command" {
  value = "az aks get-credentials --resource-group ${var.resource_group_name} --name ${azurerm_kubernetes_cluster.primary.name}"
}

output "infra_secret_name" {
  value = kubernetes_secret_v1.infra.metadata[0].name
}

output "broker_public_key_pem" {
  value     = tls_private_key.broker.public_key_pem
  sensitive = true
}
