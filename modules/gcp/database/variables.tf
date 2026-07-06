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
