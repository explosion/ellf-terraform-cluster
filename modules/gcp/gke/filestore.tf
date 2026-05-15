# ------------------
# Google Filestore
# ------------------

resource "google_filestore_instance" "nfs" {
  name     = "${var.prefix}-filestore"
  location = var.gcp_zone
  project  = var.gcp_project
  tier     = var.filestore_tier

  file_shares {
    name       = var.filestore_share_name
    capacity_gb = var.filestore_capacity_gb
  }

  networks {
    network = var.network_name
    modes   = ["MODE_IPV4"]
  }
}

# -------------------------------------------
# Kubernetes PV + PVC pointing to Filestore
# -------------------------------------------

provider "kubernetes" {
  host                   = "https://${google_container_cluster.primary.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(google_container_cluster.primary.master_auth[0].cluster_ca_certificate)
}

data "google_client_config" "default" {}

resource "kubernetes_namespace_v1" "app" {
  metadata {
    name = var.k8s_namespace
  }

  depends_on = [
    google_container_node_pool.system,
  ]
}

resource "kubernetes_storage_class_v1" "nfs" {
  metadata {
    name = "nfs"
  }
  storage_provisioner = "kubernetes.io/no-provisioner"
  reclaim_policy      = "Retain"
  volume_binding_mode = "Immediate"

  depends_on = [
    google_container_node_pool.system,
  ]
}

resource "kubernetes_persistent_volume_v1" "nfs" {
  metadata {
    name = "prodigy-nfs-pv"
  }

  spec {
    capacity = {
      storage = "${var.filestore_capacity_gb}Gi"
    }

    access_modes                     = ["ReadWriteMany"]
    persistent_volume_reclaim_policy = "Retain"
    storage_class_name               = kubernetes_storage_class_v1.nfs.metadata[0].name

    persistent_volume_source {
      nfs {
        server = google_filestore_instance.nfs.networks[0].ip_addresses[0]
        path   = "/${var.filestore_share_name}"
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim_v1" "nfs" {
  metadata {
    name      = "prodigy-nfs"
    namespace = kubernetes_namespace_v1.app.metadata[0].name
  }

  spec {
    access_modes       = ["ReadWriteMany"]
    storage_class_name = kubernetes_storage_class_v1.nfs.metadata[0].name

    resources {
      requests = {
        storage = "${var.filestore_capacity_gb}Gi"
      }
    }

    volume_name = kubernetes_persistent_volume_v1.nfs.metadata[0].name
  }
}
