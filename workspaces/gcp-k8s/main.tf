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
  # Write access only to the cluster's own repo; external repos (the
  # shared release registry) are strictly read-only.
  artifact_repos = [
    {
      project  = var.gcp_project
      location = google_artifact_registry_repository.default.location
      name     = google_artifact_registry_repository.default.repository_id
    }
  ]
  readonly_artifact_repos = var.external_artifact_repos

  buckets = [google_storage_bucket.data-bucket.self_link]
  secret_ids = {}
  enable_ssh = false

  system_node_pool_machine_type = var.system_node_pool_machine_type
  system_node_pool_size = var.system_node_pool_size
  worker_types = var.worker_types

  enable_cost_allocation = var.enable_cost_allocation

  domain = var.domain

  database_password = module.database.database_password

  # The database module's service networking connection is a VPC peering
  # operation, and so are the GKE private control plane setup and the
  # Filestore direct peering inside the cluster module. GCP allows only
  # one peering operation per network at a time; without this edge the
  # cluster races the database and fails with "a peering operation is in
  # progress on the local or peer network". The database_password input
  # above only ties the K8s secret to the database, not the cluster itself,
  # so the ordering must be explicit.
  depends_on = [module.database]
}

# ------------
# Cloud costs
# ------------

# Read access to this cluster's own rows of the shared billing export.
# Absent (not just inert) until enable_cost_collection is flipped.
module "billing" {
  count  = var.enable_cost_collection ? 1 : 0
  source = "../../modules/gcp/billing/"

  gcp_project           = var.gcp_project
  service_account_email = module.cluster.node_service_account_email

  billing_project         = var.billing_export.project
  billing_export_dataset  = var.billing_export.dataset
  billing_export_table    = var.billing_export.table
  billing_export_location = var.billing_export.location
}

