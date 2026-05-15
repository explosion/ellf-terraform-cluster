# ----------------------------
# Static IP for ingress
# ----------------------------

data "google_compute_address" "ingress" {
  name    = "${var.prefix}-lb-ip"
  region  = var.gcp_region
  project = var.gcp_project
}

# ----------------------------
# Service account
# ----------------------------

resource "google_service_account" "nomad" {
  account_id   = "${var.prefix}-nomad-sa"
  display_name = "Nomad cluster service account"
  project      = var.gcp_project
}

# Per-bucket IAM
resource "google_storage_bucket_iam_member" "nomad" {
  for_each = toset(var.buckets)

  bucket = each.value
  role   = "roles/storage.admin"
  member = "serviceAccount:${google_service_account.nomad.email}"
}

# Artifact Registry read access
resource "google_artifact_registry_repository_iam_member" "nomad" {
  for_each = {
    for repo in var.artifact_repos :
    "${repo.project}/${repo.location}/${repo.name}" => repo
  }

  project    = each.value.project
  location   = each.value.location
  repository = each.value.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${google_service_account.nomad.email}"
}

# Secret Manager access
resource "google_secret_manager_secret_iam_member" "nomad" {
  for_each = var.secret_ids

  secret_id = each.value
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.nomad.email}"
}

# Project-level roles
resource "google_project_iam_member" "nomad_logging" {
  project = var.gcp_project
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.nomad.email}"
}

resource "google_project_iam_member" "nomad_monitoring" {
  project = var.gcp_project
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.nomad.email}"
}

# ----------------------------
# Network
# ----------------------------

resource "google_compute_subnetwork" "nomad" {
  name                     = "${var.prefix}-nomad-subnet"
  ip_cidr_range            = "10.0.0.0/20"
  region                   = var.gcp_region
  network                  = var.network_name
  private_ip_google_access = true
}

resource "google_compute_route" "default_route" {
  name             = "${var.prefix}-nomad-default-route"
  dest_range       = "0.0.0.0/0"
  network          = var.network_name
  next_hop_gateway = "default-internet-gateway"
  priority         = 1000
}

resource "google_compute_router" "nomad" {
  name    = "${var.prefix}-nomad-router"
  region  = var.gcp_region
  network = var.network_name
}

resource "google_compute_router_nat" "nomad" {
  name   = "${var.prefix}-nomad-nat"
  router = google_compute_router.nomad.name
  region = var.gcp_region

  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

# ----------------------------
# Firewall
# ----------------------------

resource "google_compute_firewall" "ssh" {
  count = var.enable_ssh ? 1 : 0

  name    = "${var.prefix}-nomad-allow-ssh"
  network = var.network_name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["nomad-${var.prefix}"]
}

resource "google_compute_firewall" "internal" {
  name    = "${var.prefix}-nomad-allow-internal"
  network = var.network_name

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = [google_compute_subnetwork.nomad.ip_cidr_range]
  target_tags   = ["nomad-${var.prefix}"]
}

# ----------------------------
# Gossip encryption key
# ----------------------------

resource "random_id" "gossip_key" {
  byte_length = 32
}

# ----------------------------
# Broker RSA keypair
# ----------------------------

resource "tls_private_key" "broker" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# ----------------------------
# Server addresses for join
# ----------------------------

locals {
  server_ips = [
    for i in range(var.server_count) :
    cidrhost(google_compute_subnetwork.nomad.ip_cidr_range, 10 + i)
  ]
  server_addrs = join(", ", formatlist("\"%s\"", local.server_ips))
}

# ----------------------------
# Server instances
# ----------------------------

resource "google_compute_instance" "servers" {
  count = var.server_count

  name         = "${var.prefix}-nomad-server-${count.index}"
  machine_type = var.server_machine_type
  zone         = var.gcp_zone

  tags = ["nomad-${var.prefix}"]

  boot_disk {
    initialize_params {
      image = var.server_image
      size  = var.server_disk_size_gb
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.nomad.self_link
    network_ip = local.server_ips[count.index]
  }

  metadata_startup_script = templatefile("${path.module}/scripts/server.sh.tftpl", {
    nomad_version   = var.nomad_version
    server_count    = var.server_count
    gossip_key      = random_id.gossip_key.b64_std
    server_addrs    = local.server_addrs
    filestore_ip    = google_filestore_instance.nfs.networks[0].ip_addresses[0]
    filestore_share = var.filestore_share_name
  })

  service_account {
    email  = google_service_account.nomad.email
    scopes = ["cloud-platform"]
  }

  labels = {
    "ellf-role" = "server"
  }

  allow_stopping_for_update = true
}

# ----------------------------
# Worker instance templates
# ----------------------------

resource "google_compute_instance_template" "workers" {
  for_each = var.worker_types

  name_prefix  = "${var.prefix}-nomad-${each.value.name}-"
  machine_type = each.value.machine_type

  tags = ["nomad-${var.prefix}"]

  disk {
    source_image = var.worker_image
    disk_size_gb = var.worker_disk_size_gb
    auto_delete  = true
    boot         = true
  }

  network_interface {
    subnetwork = google_compute_subnetwork.nomad.self_link
  }

  metadata = {
    startup-script = templatefile("${path.module}/scripts/client.sh.tftpl", {
      nomad_version   = var.nomad_version
      gossip_key      = random_id.gossip_key.b64_std
      server_addrs    = local.server_addrs
      node_class      = each.value.node_class
      has_gpu         = each.value.guest_accelerator != null
      filestore_ip    = google_filestore_instance.nfs.networks[0].ip_addresses[0]
      filestore_share = var.filestore_share_name
    })
  }

  service_account {
    email  = google_service_account.nomad.email
    scopes = ["cloud-platform"]
  }

  scheduling {
    preemptible       = each.value.preemptible || each.value.spot
    automatic_restart = !(each.value.preemptible || each.value.spot)
    provisioning_model = each.value.spot ? "SPOT" : (each.value.preemptible ? "PREEMPTIBLE" : "STANDARD")
  }

  dynamic "guest_accelerator" {
    for_each = each.value.guest_accelerator != null ? [each.value.guest_accelerator] : []
    content {
      type  = guest_accelerator.value.type
      count = guest_accelerator.value.count
    }
  }

  labels = {
    "ellf-node-class" = each.value.node_class
    "ellf-worker"     = "true"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ----------------------------
# Worker managed instance groups
# ----------------------------

resource "google_compute_instance_group_manager" "workers" {
  for_each = var.worker_types

  name               = "${var.prefix}-nomad-${each.value.name}-mig"
  base_instance_name = "${var.prefix}-nomad-${each.value.name}"
  zone               = var.gcp_zone

  version {
    instance_template = google_compute_instance_template.workers[each.key].self_link
  }

  target_size = each.value.min_size
}

resource "google_compute_autoscaler" "workers" {
  for_each = var.worker_types

  name   = "${var.prefix}-nomad-${each.value.name}-autoscaler"
  zone   = var.gcp_zone
  target = google_compute_instance_group_manager.workers[each.key].id

  autoscaling_policy {
    min_replicas    = each.value.min_size
    max_replicas    = each.value.max_size
    cooldown_period = 60

    cpu_utilization {
      target = 0.7
    }
  }
}
