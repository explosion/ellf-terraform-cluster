locals {
  gcp_region = substr(var.gcp_zone, 0, length(var.gcp_zone)-2)
}


provider "random" {
}

provider "google" {
  project     = var.gcp_project
  region      = local.gcp_region
}

# -------------
# Network
# -------------


resource "google_compute_network" "cluster" {
  project = var.gcp_project
  name = var.network_name
  auto_create_subnetworks = false
  delete_default_routes_on_create = true
}

# --------------------
# Container registry
# --------------------

resource "google_artifact_registry_repository" "default" {
  location      = local.gcp_region
  repository_id = var.repository_id
  description   = "Container Repository"
  format        = "DOCKER"
}

# --------------
# Bucket setup
# --------------

resource "google_storage_bucket" "data-bucket" {
  name = "${var.gcp_project}-data"
  project = var.gcp_project
  location = var.bucket_location
  force_destroy = true
}

# ---------
# Database
# ---------

module "database" {
  source = "../../modules/gcp/database/"
  gcp_project = var.gcp_project
  gcp_zone = var.gcp_zone
  network_id = google_compute_network.cluster.id
  user = var.database_user
  name = var.database_name
  depends_on = [google_compute_network.cluster]
}

# ---------
# Cluster
# ---------

module "cluster" {
  source = "../../modules/gcp/gke"
  gcp_project = var.gcp_project
  gcp_region = local.gcp_region
  gcp_zone = var.gcp_zone
  prefix = "cluster"
  network_name = google_compute_network.cluster.name
  artifact_repos = concat(
    [
      {
        project  = var.gcp_project
        location = google_artifact_registry_repository.default.location
        name     = google_artifact_registry_repository.default.repository_id
      }
    ],
    var.external_artifact_repos,
  )

  buckets = [google_storage_bucket.data-bucket.self_link]
  secret_ids = {}
  enable_ssh = false

  system_node_pool_machine_type = var.system_node_pool_machine_type
  system_node_pool_size = var.system_node_pool_size
  worker_types = var.worker_types

  domain = var.domain

  database_host     = module.database.database_private_ip
  database_name     = module.database.database_name
  database_user     = module.database.database_user
  database_password = module.database.database_password
}

