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
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin = "azure"
    service_cidr   = "10.8.0.0/20"
    dns_service_ip = "10.8.0.10"
  }
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

  min_count          = each.value.min_size
  max_count          = each.value.max_size
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
