# ----------
# Static IP
# ----------

# Look up the reserved global IP that the GKE Ingress annotation references.
# The IP is created once during project setup (ptc gcp create-project) with
# name "{project}-web" and should already exist before terraform runs.
# The ingress IP is created by `pdcli setup environment` (regional static IP)
# and persists across terraform runs to avoid DNS rebinding.
data "google_compute_address" "ingress" {
  name    = var.ingress_ip_name
  project = var.gcp_project
  region  = var.gcp_region
}

# ----
# IAM
# ----

resource "google_service_account" "gke_nodes" {
  account_id   = "${var.prefix}-gke-sa"
  display_name = "GKE node service account"
}

resource "google_storage_bucket_iam_member" "default" {
  count  = length(var.buckets)
  bucket = var.buckets[count.index]
  role   = "roles/storage.admin"
  member = google_service_account.gke_nodes.member
}

resource "google_artifact_registry_repository_iam_member" "default" {
  count      = length(var.artifact_repos)
  project    = var.artifact_repos[count.index].project
  location   = var.artifact_repos[count.index].location
  repository = var.artifact_repos[count.index].name
  role       = "roles/artifactregistry.writer"
  member     = google_service_account.gke_nodes.member
}

resource "google_secret_manager_secret_iam_member" "secret_ids" {
  count     = length(var.secret_ids)
  secret_id = var.secret_ids[count.index]
  role      = "roles/secretmanager.secretAccessor"
  member    = google_service_account.gke_nodes.member
}

# Project-level roles needed for GKE nodes
resource "google_project_iam_member" "log_writer" {
  project = var.gcp_project
  role    = "roles/logging.logWriter"
  member  = google_service_account.gke_nodes.member
}

resource "google_project_iam_member" "metric_writer" {
  project = var.gcp_project
  role    = "roles/monitoring.metricWriter"
  member  = google_service_account.gke_nodes.member
}

resource "google_project_iam_member" "monitoring_viewer" {
  project = var.gcp_project
  role    = "roles/monitoring.viewer"
  member  = google_service_account.gke_nodes.member
}

resource "google_project_iam_member" "artifact_registry_reader" {
  project = var.gcp_project
  role    = "roles/artifactregistry.reader"
  member  = google_service_account.gke_nodes.member
}

# Allow the Kubernetes service account to impersonate the GCP service
# account via Workload Identity. Without this binding the GKE metadata
# proxy cannot mint tokens for the GSA, so any google-auth call from
# inside the pod fails with "iam.serviceAccounts.getAccessToken denied".
resource "google_service_account_iam_member" "workload_identity" {
  service_account_id = google_service_account.gke_nodes.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.gcp_project}.svc.id.goog[${var.k8s_namespace}/${var.k8s_service_account}]"
}

# --------
# Network
# --------

resource "google_compute_subnetwork" "gke_subnet" {
  project       = var.gcp_project
  region        = var.gcp_region
  name          = "${var.prefix}-gke-subnet"
  network       = var.network_name
  ip_cidr_range = "10.0.0.0/20"

  secondary_ip_range {
    range_name    = "${var.prefix}-pods"
    ip_cidr_range = "10.4.0.0/14"
  }

  secondary_ip_range {
    range_name    = "${var.prefix}-services"
    ip_cidr_range = "10.8.0.0/20"
  }

  private_ip_google_access = true
}

resource "google_compute_route" "default_route" {
  name             = "${var.prefix}-default-route"
  dest_range       = "0.0.0.0/0"
  network          = var.network_name
  next_hop_gateway = "default-internet-gateway"
  priority         = 100
}

# NAT for outbound internet access from private nodes
resource "google_compute_router" "default" {
  name    = "${var.prefix}-nat-router"
  network = var.network_name
  region  = var.gcp_region
}

resource "google_compute_router_nat" "default" {
  name   = "${var.prefix}-nat-gateway"
  router = google_compute_router.default.name
  region = google_compute_router.default.region

  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  subnetwork {
    name                    = google_compute_subnetwork.gke_subnet.name
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# SSH firewall rule (conditional)
resource "google_compute_firewall" "allow_ssh" {
  count     = var.enable_ssh ? 1 : 0
  name      = "${var.prefix}-gke-ssh"
  direction = "INGRESS"
  network   = var.network_name

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["gke-${var.prefix}"]

  allow {
    protocol = "tcp"
    ports    = [22]
  }
}

# -----------
# GKE Cluster
# -----------

resource "google_container_cluster" "primary" {
  name     = "${var.prefix}-gke"
  location = var.gcp_zone
  project  = var.gcp_project

  # Use a separately managed node pool
  remove_default_node_pool = true
  initial_node_count       = 1

  network    = var.network_name
  subnetwork = google_compute_subnetwork.gke_subnet.name

  min_master_version = var.cluster_version

  release_channel {
    channel = var.release_channel
  }

  # VPC-native (alias IP) networking
  ip_allocation_policy {
    cluster_secondary_range_name  = google_compute_subnetwork.gke_subnet.secondary_ip_range[0].range_name
    services_secondary_range_name = google_compute_subnetwork.gke_subnet.secondary_ip_range[1].range_name
  }

  # Private nodes with public endpoint
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }

  # Workload Identity
  workload_identity_config {
    workload_pool = "${var.gcp_project}.svc.id.goog"
  }

  # Logging and monitoring
  logging_service    = "logging.googleapis.com/kubernetes"
  monitoring_service = "monitoring.googleapis.com/kubernetes"

  depends_on = [
    google_compute_subnetwork.gke_subnet,
  ]
}

# -----------------
# System Node Pool
# -----------------

resource "google_container_node_pool" "system" {
  name     = "system"
  location = google_container_cluster.primary.location
  cluster  = google_container_cluster.primary.name
  project  = var.gcp_project

  initial_node_count = var.system_node_pool_size

  node_config {
    machine_type    = var.system_node_pool_machine_type
    service_account = google_service_account.gke_nodes.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    labels = {
      "ellf/role" = "system"
    }
  }

  lifecycle {
    ignore_changes = [
      node_config[0].resource_labels,
      node_config[0].kubelet_config,
    ]
  }
}

# -----------------
# Worker Node Pools
# -----------------

resource "google_container_node_pool" "workers" {
  for_each = var.worker_types

  name     = each.value.name
  location = google_container_cluster.primary.location
  cluster  = google_container_cluster.primary.name
  project  = var.gcp_project

  # Autoscaling: min/max are always provided by the CLI
  autoscaling {
    min_node_count = each.value.min_size
    max_node_count = each.value.max_size
  }

  node_config {
    machine_type    = each.value.machine_type
    preemptible     = each.value.preemptible
    spot            = each.value.spot
    service_account = google_service_account.gke_nodes.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    labels = {
      "ellf/node-class" = each.value.node_class
      "ellf/worker"     = "true"
    }

    # GPU configuration
    dynamic "guest_accelerator" {
      for_each = each.value.guest_accelerator != null ? [each.value.guest_accelerator] : []
      content {
        type  = guest_accelerator.value.type
        count = guest_accelerator.value.count

        gpu_driver_installation_config {
          gpu_driver_version = "DEFAULT"
        }
      }
    }

    # GPU nodes get a taint so only GPU workloads are scheduled
    dynamic "taint" {
      for_each = each.value.guest_accelerator != null ? [1] : []
      content {
        key    = "nvidia.com/gpu"
        value  = "present"
        effect = "NO_SCHEDULE"
      }
    }
  }

  lifecycle {
    ignore_changes = [
      node_config[0].resource_labels,
      node_config[0].kubelet_config,
    ]
  }
}
