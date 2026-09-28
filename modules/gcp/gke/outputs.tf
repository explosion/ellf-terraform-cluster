output "cluster_name" {
  description = "Name of the GKE cluster."
  value       = google_container_cluster.primary.name
}

output "cluster_endpoint" {
  description = "Endpoint of the GKE cluster."
  value       = google_container_cluster.primary.endpoint
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "Base64-encoded CA certificate of the GKE cluster."
  value       = google_container_cluster.primary.master_auth[0].cluster_ca_certificate
  sensitive   = true
}

output "cluster_location" {
  description = "Location (zone) of the GKE cluster."
  value       = google_container_cluster.primary.location
}

output "nfs_pvc_name" {
  description = "Name of the Kubernetes PVC for the shared volume workloads should mount (depends on shared_storage_stage)."
  value = (
    local.use_csi_volume
    ? kubernetes_persistent_volume_claim_v1.filestore[0].metadata[0].name
    : kubernetes_persistent_volume_claim_v1.nfs[0].metadata[0].name
  )
}

output "node_service_account_email" {
  description = "Email of the GKE node service account."
  value       = google_service_account.gke_nodes.email
}

output "get_credentials_command" {
  description = "gcloud command to configure kubectl."
  value       = "gcloud container clusters get-credentials ${google_container_cluster.primary.name} --zone ${google_container_cluster.primary.location} --project ${var.gcp_project}"
}

output "ingress_ip" {
  description = "Reserved static IP address for the cluster ingress (regional)."
  value       = data.google_compute_address.ingress.address
}

output "infra_secret_name" {
  description = "Name of the Kubernetes Secret containing infra credentials."
  value       = kubernetes_secret_v1.infra.metadata[0].name
}

output "broker_public_key_pem" {
  description = "PEM-encoded public key for broker registration with PAM."
  value       = tls_private_key.broker.public_key_pem
}
