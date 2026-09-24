# ----------------------------
# AKS cluster
# ----------------------------

resource "azurerm_kubernetes_cluster" "primary" {
  name                = "${var.prefix}-aks"
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = "${var.prefix}-aks"
  kubernetes_version  = var.cluster_version

  private_cluster_enabled = false

  default_node_pool {
    name           = "system"
    vm_size        = var.system_node_pool_vm_size
    node_count     = var.system_node_pool_size
    vnet_subnet_id = var.vnet_subnet_id

    node_labels = {
      "ellf/role" = "system"
    }

    # Reserve the system pool for platform components (broker, traefik,
    # cert-manager, NFS). Recipe Jobs lack the toleration and therefore
    # cannot accidentally schedule here when their worker_type doesn't
    # resolve or a customer leaves --worker-class unset. azurerm 4.x only
    # lets the default pool carry AKS's own CriticalAddonsOnly=true:NoSchedule
    # taint (not the ellf/role one GKE and EKS use), so the platform
    # components tolerate both.
    only_critical_addons_enabled = true
  }

  identity {
    type = "SystemAssigned"
  }

  # Workload identity: pods labelled azure.workload.identity/use=true that
  # run as the cluster's service account get a token for the workload
  # identity below.
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  network_profile {
    network_plugin = "azure"
    service_cidr   = "10.8.0.0/20"
    dns_service_ip = "10.8.0.10"
  }
}

# ----------------------------
# Workload identity
# ----------------------------

# The counterpart of GKE Workload Identity in modules/gcp/gke and EKS Pod
# Identity in modules/aws/eks: the broker and the recipe Jobs it launches run
# as one Kubernetes service account, federated to this managed identity.
resource "azurerm_user_assigned_identity" "workload" {
  name                = "${var.prefix}-aks-workload"
  location            = var.location
  resource_group_name = var.resource_group_name
}

resource "azurerm_federated_identity_credential" "workload" {
  name                      = "${var.prefix}-aks-${var.k8s_namespace}-${var.k8s_service_account}"
  user_assigned_identity_id = azurerm_user_assigned_identity.workload.id
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = azurerm_kubernetes_cluster.primary.oidc_issuer_url
  subject                   = "system:serviceaccount:${var.k8s_namespace}:${var.k8s_service_account}"
}

# Object read/write plus listing on the cluster's data storage, the same
# access the gcp and aws modules grant.
resource "azurerm_role_assignment" "workload_storage" {
  count                = length(var.storage_container_ids)
  scope                = var.storage_container_ids[count.index]
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.workload.principal_id
}

# ----------------------------
# Worker node pools
# ----------------------------

resource "azurerm_kubernetes_cluster_node_pool" "workers" {
  for_each = var.worker_types

  name                  = each.value.name
  kubernetes_cluster_id = azurerm_kubernetes_cluster.primary.id
  vm_size               = each.value.vm_size
  vnet_subnet_id        = var.vnet_subnet_id

  priority        = each.value.spot ? "Spot" : "Regular"
  eviction_policy = each.value.spot ? "Delete" : null
  spot_max_price  = each.value.spot ? -1 : null

  min_count            = each.value.min_size
  max_count            = each.value.max_size
  auto_scaling_enabled = true

  node_labels = {
    "ellf/node-class" = each.value.node_class
    "ellf/worker"     = "true"
  }

  node_taints = each.value.gpu != null ? ["nvidia.com/gpu=present:NoSchedule"] : []

  lifecycle {
    ignore_changes = [node_count]
  }
}
