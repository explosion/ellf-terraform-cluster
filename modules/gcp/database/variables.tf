variable "gcp_project" {
  description = "Project"
}

variable "gcp_zone" {
  description = "Zone"
}

variable "network_id" {
  description = "Network"
}

variable "user" {
  description = "User"
}

variable "name" {
  description = "DB Name"
}

variable "ipv4_enabled" {
  description = "Whether the instance gets a public IP. Customer clusters stay private by default; pam opts in explicitly since its tooling connects via cloud-sql-proxy over the public IP (no --private-ip support)."
  type        = bool
  default     = false
}

variable "deletion_protection" {
  description = "Refuse to delete the instance (in terraform and in the Cloud SQL API). Deleting it also deletes its automated backups, so this is only lifted for a deliberate data-deleting destroy."
  type        = bool
  default     = true
}
