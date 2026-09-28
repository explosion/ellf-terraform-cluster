# ------------------
# Google Filestore
# ------------------
#
# Two ways to back the shared ReadWriteMany volume; shared_storage_stage
# (see variables.tf) picks which exist and which one workloads use.

locals {
  legacy_filestore = var.shared_storage_stage != "csi"
  csi_filestore    = var.shared_storage_stage != "legacy"
  use_csi_volume   = contains(["cutover", "csi"], var.shared_storage_stage)
}

resource "google_filestore_instance" "nfs" {
  count    = local.legacy_filestore ? 1 : 0
  name     = "${var.prefix}-filestore"
  location = var.gcp_zone
  project  = var.gcp_project
  tier     = var.filestore_tier

  file_shares {
    name        = var.filestore_share_name
    capacity_gb = var.filestore_capacity_gb
  }

  networks {
    network = var.network_name
    modes   = ["MODE_IPV4"]
  }

  # Filestore's direct peering and the GKE private control plane peering
  # both mutate the VPC's peering config, and GCP only allows one peering
  # operation per network at a time — creating them concurrently fails
  # with "a peering operation is in progress". The PV that consumes this
  # instance waits on the system node pool anyway, so ordering after the
  # cluster costs nothing.
  depends_on = [google_container_cluster.primary]
}

# ----------------------------------------------------
# Kubernetes PV + PVC pointing to the legacy instance
# ----------------------------------------------------

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
  count = local.legacy_filestore ? 1 : 0
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
  count = local.legacy_filestore ? 1 : 0
  metadata {
    name = "prodigy-nfs-pv"
  }

  spec {
    capacity = {
      storage = "${var.filestore_capacity_gb}Gi"
    }

    access_modes                     = ["ReadWriteMany"]
    persistent_volume_reclaim_policy = "Retain"
    storage_class_name               = kubernetes_storage_class_v1.nfs[0].metadata[0].name

    persistent_volume_source {
      nfs {
        server = google_filestore_instance.nfs[0].networks[0].ip_addresses[0]
        path   = "/${var.filestore_share_name}"
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim_v1" "nfs" {
  count = local.legacy_filestore ? 1 : 0
  metadata {
    name      = "prodigy-nfs"
    namespace = kubernetes_namespace_v1.app.metadata[0].name
  }

  spec {
    access_modes       = ["ReadWriteMany"]
    storage_class_name = kubernetes_storage_class_v1.nfs[0].metadata[0].name

    resources {
      requests = {
        storage = "${var.filestore_capacity_gb}Gi"
      }
    }

    volume_name = kubernetes_persistent_volume_v1.nfs[0].metadata[0].name
  }
}

# These resources predate shared_storage_stage; keep existing state
# attached instead of planning a destroy and recreate.
moved {
  from = google_filestore_instance.nfs
  to   = google_filestore_instance.nfs[0]
}

moved {
  from = kubernetes_storage_class_v1.nfs
  to   = kubernetes_storage_class_v1.nfs[0]
}

moved {
  from = kubernetes_persistent_volume_v1.nfs
  to   = kubernetes_persistent_volume_v1.nfs[0]
}

moved {
  from = kubernetes_persistent_volume_claim_v1.nfs
  to   = kubernetes_persistent_volume_claim_v1.nfs[0]
}

# ---------------------------------------------------
# CSI-provisioned Filestore (Basic HDD, from 100 GiB)
# ---------------------------------------------------

resource "kubernetes_storage_class_v1" "filestore" {
  count = local.csi_filestore ? 1 : 0
  metadata {
    name = "filestore-standard-retain"
  }
  storage_provisioner = "filestore.csi.storage.gke.io"
  # Deleting the PVC (or the namespace) must not delete the instance's data.
  reclaim_policy         = "Retain"
  volume_binding_mode    = "Immediate"
  allow_volume_expansion = true

  parameters = {
    tier = "standard"
    # The driver otherwise peers with the project's "default" VPC.
    network = var.network_name
  }

  allowed_topologies {
    match_label_expressions {
      key    = "topology.gke.io/zone"
      values = [var.gcp_zone]
    }
  }

  depends_on = [
    google_container_cluster.primary,
    google_container_node_pool.system,
  ]
}

resource "kubernetes_persistent_volume_claim_v1" "filestore" {
  count = local.csi_filestore ? 1 : 0
  metadata {
    name      = "prodigy-shared"
    namespace = kubernetes_namespace_v1.app.metadata[0].name
  }

  spec {
    access_modes       = ["ReadWriteMany"]
    storage_class_name = kubernetes_storage_class_v1.filestore[0].metadata[0].name

    resources {
      requests = {
        storage = "${var.shared_volume_capacity_gb}Gi"
      }
    }
  }

  # Binding waits for the driver to create the Filestore instance, which
  # takes several minutes.
  timeouts {
    create = "20m"
  }
}
