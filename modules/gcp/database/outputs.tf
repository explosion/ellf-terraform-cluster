output "database_public_ip" {
  value = google_sql_database_instance.default.public_ip_address
}

output "database_private_ip" {
  value = google_sql_database_instance.default.private_ip_address
}


output "database_user" {
  value = google_sql_user.user.name
}

output "database_password" {
  value     = random_string.password.result
  sensitive = true
}

output "database_name" {
  value = google_sql_database.default.name
}

# Ordering handle, not data: consume this wherever another VPC peering
# operation (GKE private control plane, Filestore) must wait for the
# private-services-access peering to finish.
output "vpc_connection" {
  value = google_service_networking_connection.db_vpc_connection.id
}


