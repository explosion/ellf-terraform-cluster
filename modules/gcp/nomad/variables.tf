# -----------------------
# Where you're deploying
# -----------------------

variable "gcp_project" {
  description = "The project in which all GCP resources will be launched."
  type        = string
}

variable "gcp_region" {
  description = "The region in which all GCP resources will be launched."
  type        = string
}

variable "gcp_zone" {
  description = "The zone in which all GCP resources will be launched."
  type        = string
}

variable "prefix" {
  description = "Prefix to attach to resource names."
  type        = string
}

variable "network_name" {
  description = "Name of the network to locate resources within."
  type        = string
}

# ----
# IAM
# ----

variable "buckets" {
  description = "Buckets the nodes should have access to."
  default     = []
}

variable "artifact_repos" {
  description = "Artifact repositories the cluster should have access to."
  type        = list(any)
  default     = []
}

variable "secret_ids" {
  description = "Secrets the cluster should have access to."
  default     = {}
}

# ---------------------
# Options and settings
# ---------------------

variable "enable_ssh" {
  description = "Enable SSH firewall rule."
  type        = bool
  default     = true
}

variable "server_machine_type" {
  description = "Machine type for Nomad server instances."
  type        = string
  default     = "e2-medium"
}

variable "server_count" {
  description = "Number of Nomad server instances (should be 3 or 5 for raft consensus)."
  type        = number
  default     = 3
}

variable "worker_types" {
  description = "Configurations for worker instance groups. Each entry becomes a managed instance group."
  type = map(
    object({
      name         = string
      node_class   = string
      machine_type = string
      preemptible  = optional(bool, false)
      spot         = optional(bool, false)
      min_size     = number
      max_size     = number
      guest_accelerator = optional(object({
        type  = string
        count = number
      }))
    })
  )
  default = {}
}

# -------
# Ingress
# -------

variable "domain" {
  description = "Domain name for the cluster ingress."
  type        = string
}

# ---------
# Filestore
# ---------

variable "filestore_tier" {
  description = "Filestore service tier."
  type        = string
  default     = "BASIC_HDD"
}

variable "filestore_capacity_gb" {
  description = "Filestore capacity in GB (minimum 1024 for BASIC_HDD)."
  type        = number
  default     = 1024
}

variable "filestore_share_name" {
  description = "Name of the Filestore file share."
  type        = string
  default     = "prodigy_data"
}

# -------
# Nomad
# -------

variable "nomad_version" {
  description = "Nomad version to install on instances."
  type        = string
  default     = "1.7.6"
}

variable "traefik_version" {
  description = "Traefik Docker image tag for the ingress job."
  type        = string
  default     = "3.0"
}

variable "server_disk_size_gb" {
  description = "Boot disk size in GB for server instances."
  type        = number
  default     = 50
}

variable "server_image" {
  description = "Boot image for server instances."
  type        = string
  default     = "ubuntu-os-cloud/ubuntu-2204-lts"
}

variable "worker_disk_size_gb" {
  description = "Boot disk size in GB for worker instances."
  type        = number
  default     = 100
}

variable "worker_image" {
  description = "Boot image for worker instances."
  type        = string
  default     = "ubuntu-os-cloud/ubuntu-2204-lts"
}

# -------
# Secrets
# -------

variable "database_password" {
  description = "Database password."
  type        = string
  sensitive   = true
}

variable "database_host" {
  description = "Database private IP or hostname."
  type        = string
}

variable "database_user" {
  description = "Database user."
  type        = string
}

variable "database_name" {
  description = "Database name."
  type        = string
}
