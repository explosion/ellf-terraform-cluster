locals {
  gcp_region = substr(var.gcp_zone, 0, length(var.gcp_zone) - 2)
}

# TODO: Enable Service Networking API for this

# --------------------------------------
# Database that workers will write tasks into
# --------------------------------------

resource "google_sql_database_instance" "default" {
  # Need to leave name unspecified here, because we need it
  # it to be automatically assigned.
  database_version = "POSTGRES_14"
  region           = local.gcp_region
  # Blocks terraform from deleting the instance; deleting it also deletes
  # its automated backups, i.e. every annotation the cluster holds.
  deletion_protection = var.deletion_protection
  settings {
    tier = "db-g1-small"
    # The API-side counterpart: also blocks deletes from the console/gcloud.
    deletion_protection_enabled = var.deletion_protection
    ip_configuration {
      ipv4_enabled                                  = var.ipv4_enabled
      private_network                               = var.network_id
      enable_private_path_for_google_cloud_services = true

      #authorized_networks {
      #  value = data.google_compute_address.bastion_ip.address
      #  name  = "bastion-server"
      #}
    }

    backup_configuration {
      enabled    = "true"
      start_time = "19:19"
    }
  }

  depends_on = [google_service_networking_connection.db_vpc_connection]

  lifecycle {
    # 'ellf infra pause' / 'hibernate' stop the instance (NEVER) and resume /
    # wake start it again; an apply in between must not start it behind
    # their back.
    ignore_changes = [settings[0].activation_policy]
  }
}

resource "random_string" "password" {
  length  = 32
  special = false
}

resource "random_string" "migration_password" {
  length  = 32
  special = false
}


resource "google_sql_database" "default" {
  name      = var.name
  instance  = google_sql_database_instance.default.name
  charset   = "UTF8"
  collation = "en_US.UTF8"
}

resource "google_sql_user" "user" {
  name     = var.user
  password = random_string.password.result
  instance = google_sql_database_instance.default.name
}

# In order to connect to the DB from a VPC, we need to set up
# this connection. Wasn't very intuitive to me, but okay.
resource "google_compute_global_address" "sql_private_ip" {
  name          = "private-ip-address"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = var.network_id
}

resource "google_service_networking_connection" "db_vpc_connection" {
  network                 = var.network_id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.sql_private_ip.name]
}
