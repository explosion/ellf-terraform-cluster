output "server_ips" {
  value = google_compute_instance.servers[*].network_interface[0].network_ip
}

output "server_names" {
  value = google_compute_instance.servers[*].name
}

output "service_account_email" {
  value = google_service_account.nomad.email
}

output "filestore_ip" {
  value = google_filestore_instance.nfs.networks[0].ip_addresses[0]
}

output "filestore_share_name" {
  value = var.filestore_share_name
}

output "ingress_ip" {
  value = data.google_compute_address.ingress.address
}

output "gossip_key" {
  value     = random_id.gossip_key.b64_std
  sensitive = true
}

output "broker_public_key_pem" {
  value     = tls_private_key.broker.public_key_pem
  sensitive = true
}

output "traefik_job_spec" {
  value = templatefile("${path.module}/jobs/traefik.nomad.hcl", {
    traefik_version = var.traefik_version
  })
}
