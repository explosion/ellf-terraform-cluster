variable "prefix" {
  description = "Prefix for resource names."
  type        = string
}

variable "resource_group_name" {
  description = "Azure resource group name."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "delegated_subnet_id" {
  description = "Subnet ID delegated to PostgreSQL flexible server."
  type        = string
}

variable "private_dns_zone_id" {
  description = "Private DNS zone ID for PostgreSQL name resolution."
  type        = string
}

variable "user" {
  description = "Administrator login username."
  type        = string
}

variable "name" {
  description = "Name of the database to create."
  type        = string
}

variable "sku_name" {
  description = "SKU name for the PostgreSQL flexible server."
  type        = string
  default     = "B_Standard_B1ms"
}

variable "engine_version" {
  description = "PostgreSQL engine version."
  type        = string
  default     = "14"
}

variable "storage_mb" {
  description = "Storage in MB for the PostgreSQL flexible server."
  type        = number
  default     = 32768
}
