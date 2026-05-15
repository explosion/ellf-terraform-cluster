resource "random_string" "password" {
  length  = 32
  special = false
}

resource "azurerm_postgresql_flexible_server" "default" {
  name                = "${var.prefix}-postgres"
  resource_group_name = var.resource_group_name
  location            = var.location
  version             = var.engine_version
  sku_name            = var.sku_name
  storage_mb          = var.storage_mb

  administrator_login    = var.user
  administrator_password = random_string.password.result

  delegated_subnet_id = var.delegated_subnet_id
  private_dns_zone_id = var.private_dns_zone_id

  public_network_access_enabled = false

  backup_retention_days = 7
  zone                  = "1"
}

resource "azurerm_postgresql_flexible_server_database" "default" {
  name      = var.name
  server_id = azurerm_postgresql_flexible_server.default.id
  charset   = "UTF8"
  collation = "en_US.UTF8"
}
