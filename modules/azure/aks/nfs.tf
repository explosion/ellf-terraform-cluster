# ----------------------------
# Azure Files NFS
# ----------------------------

resource "azurerm_storage_account" "nfs" {
  name                     = var.storage_account_name
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Premium"
  account_replication_type = "LRS"
  account_kind             = "FileStorage"
  min_tls_version          = "TLS1_2"

  https_traffic_only_enabled = false
}

resource "azurerm_storage_share" "nfs" {
  name               = "prodigy-data"
  storage_account_id = azurerm_storage_account.nfs.id
  quota              = var.nfs_storage_gb
  enabled_protocol   = "NFS"
}

# ----------------------------
# Kubernetes provider
# ----------------------------

provider "kubernetes" {
  host                   = azurerm_kubernetes_cluster.primary.kube_config[0].host
  client_certificate     = base64decode(azurerm_kubernetes_cluster.primary.kube_config[0].client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.primary.kube_config[0].client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.primary.kube_config[0].cluster_ca_certificate)
}

# ----------------------------
# Kubernetes namespace
# ----------------------------

resource "kubernetes_namespace_v1" "app" {
  metadata {
    name = var.k8s_namespace
  }

  depends_on = [azurerm_kubernetes_cluster.primary]
}

# ----------------------------
# NFS storage class + PV/PVC
# ----------------------------

resource "kubernetes_storage_class_v1" "nfs" {
  metadata {
    name = "azure-nfs"
  }

  storage_provisioner = "kubernetes.io/no-provisioner"
  reclaim_policy      = "Retain"
}

resource "kubernetes_persistent_volume_v1" "nfs" {
  metadata {
    name = "${var.prefix}-nfs-pv"
  }

  spec {
    capacity = {
      storage = "${var.nfs_storage_gb}Gi"
    }

    access_modes       = ["ReadWriteMany"]
    storage_class_name = kubernetes_storage_class_v1.nfs.metadata[0].name

    persistent_volume_source {
      csi {
        driver        = "file.csi.azure.com"
        volume_handle = "${var.storage_account_name}-prodigy-data"

        volume_attributes = {
          storageAccount = var.storage_account_name
          shareName      = azurerm_storage_share.nfs.name
          protocol       = "nfs"
        }
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
        storage = "${var.nfs_storage_gb}Gi"
      }
    }

    volume_name = kubernetes_persistent_volume_v1.nfs.metadata[0].name
  }
}
