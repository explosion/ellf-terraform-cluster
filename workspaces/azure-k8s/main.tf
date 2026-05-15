provider "azurerm" {
  features {}
}

provider "random" {
}

# ----------------
# Resource group
# ----------------

resource "azurerm_resource_group" "cluster" {
  name     = var.resource_group_name
  location = var.location
}

# -------------
# Network
# -------------

resource "azurerm_virtual_network" "cluster" {
  name                = var.network_name
  address_space       = [var.vnet_cidr]
  location            = azurerm_resource_group.cluster.location
  resource_group_name = azurerm_resource_group.cluster.name
}

resource "azurerm_subnet" "aks" {
  name                 = "aks-subnet"
  resource_group_name  = azurerm_resource_group.cluster.name
  virtual_network_name = azurerm_virtual_network.cluster.name
  address_prefixes     = [cidrsubnet(var.vnet_cidr, 4, 0)]
}

resource "azurerm_subnet" "database" {
  name                 = "database-subnet"
  resource_group_name  = azurerm_resource_group.cluster.name
  virtual_network_name = azurerm_virtual_network.cluster.name
  address_prefixes     = [cidrsubnet(var.vnet_cidr, 8, 16)]

  delegation {
    name = "postgresql"

    service_delegation {
      name    = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

# -------------
# NAT Gateway
# -------------

resource "azurerm_public_ip" "nat" {
  name                = "${var.network_name}-nat-ip"
  location            = azurerm_resource_group.cluster.location
  resource_group_name = azurerm_resource_group.cluster.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_nat_gateway" "cluster" {
  name                = "${var.network_name}-nat-gw"
  location            = azurerm_resource_group.cluster.location
  resource_group_name = azurerm_resource_group.cluster.name
}

resource "azurerm_nat_gateway_public_ip_association" "cluster" {
  nat_gateway_id       = azurerm_nat_gateway.cluster.id
  public_ip_address_id = azurerm_public_ip.nat.id
}

resource "azurerm_subnet_nat_gateway_association" "aks" {
  subnet_id      = azurerm_subnet.aks.id
  nat_gateway_id = azurerm_nat_gateway.cluster.id
}

# ----------------------------
# Private DNS for PostgreSQL
# ----------------------------

resource "azurerm_private_dns_zone" "postgres" {
  name                = "${var.resource_group_name}.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.cluster.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "postgres" {
  name                  = "postgres-vnet-link"
  private_dns_zone_name = azurerm_private_dns_zone.postgres.name
  resource_group_name   = azurerm_resource_group.cluster.name
  virtual_network_id    = azurerm_virtual_network.cluster.id
}

# --------------------
# Container registry
# --------------------

resource "azurerm_container_registry" "default" {
  name                = var.acr_name
  resource_group_name = azurerm_resource_group.cluster.name
  location            = azurerm_resource_group.cluster.location
  sku                 = "Basic"
  admin_enabled       = false
}

# --------------
# Data storage
# --------------

resource "azurerm_storage_account" "data" {
  name                     = var.data_storage_account_name
  resource_group_name      = azurerm_resource_group.cluster.name
  location                 = azurerm_resource_group.cluster.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "data" {
  name               = "data"
  storage_account_id = azurerm_storage_account.data.id
}

# ---------
# Database
# ---------

module "database" {
  source              = "../../modules/azure/database/"
  prefix              = "cluster"
  resource_group_name = azurerm_resource_group.cluster.name
  location            = azurerm_resource_group.cluster.location
  delegated_subnet_id = azurerm_subnet.database.id
  private_dns_zone_id = azurerm_private_dns_zone.postgres.id
  user                = var.database_user
  name                = var.database_name

  depends_on = [azurerm_private_dns_zone_virtual_network_link.postgres]
}

# ---------
# Cluster
# ---------

module "cluster" {
  source              = "../../modules/azure/aks"
  prefix              = "cluster"
  resource_group_name = azurerm_resource_group.cluster.name
  location            = azurerm_resource_group.cluster.location
  vnet_subnet_id      = azurerm_subnet.aks.id

  system_node_pool_vm_size = var.system_node_pool_vm_size
  system_node_pool_size    = var.system_node_pool_size
  worker_types             = var.worker_types

  domain               = var.domain
  storage_account_name = var.storage_account_name

  database_host     = module.database.database_fqdn
  database_name     = module.database.database_name
  database_user     = module.database.database_user
  database_password = module.database.database_password
}

# ----------------------------
# ACR pull permission for AKS
# ----------------------------

resource "azurerm_role_assignment" "aks_acr_pull" {
  principal_id         = module.cluster.kubelet_identity_object_id
  role_definition_name = "AcrPull"
  scope                = azurerm_container_registry.default.id
}
