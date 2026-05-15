output "database_address" {
  value = aws_db_instance.default.address
}

output "database_user" {
  value = aws_db_instance.default.username
}

output "database_password" {
  value     = random_string.password.result
  sensitive = true
}

output "database_name" {
  value = aws_db_instance.default.db_name
}

output "database_port" {
  value = aws_db_instance.default.port
}

output "security_group_id" {
  value = aws_security_group.database.id
}
