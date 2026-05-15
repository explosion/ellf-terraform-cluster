output "database_fqdn" {
  value = azurerm_postgresql_flexible_server.default.fqdn
}

output "database_user" {
  value = azurerm_postgresql_flexible_server.default.administrator_login
}

output "database_password" {
  value     = random_string.password.result
  sensitive = true
}

output "database_name" {
  value = azurerm_postgresql_flexible_server_database.default.name
}
