# -----------------------
# Where you're deploying
# -----------------------

variable "gcp_project" {
  description = "The project in which all GCP resources will be launched."
}

variable "gcp_zone" {
  description = "The region in which all GCP resources will be launched."
  type        = string
}

variable "domain" {
  type = string
}

# ---------------------
# Options and settings
# ---------------------

variable "enable_ssh" {
  type    = bool
  default = true
}

variable "worker_types" {
  description = "Configurations for worker node pools"
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

variable "system_node_pool_machine_type" {
  description = "Machine type for system node pool"
  type        = string
}

variable "system_node_pool_size" {
  description = "Size of system node pool"
  type        = string
}

variable "bucket_location" {
  description = "The location to store the bucket"
  default     = "EU"
}

# ------------------
# Names and details
# ------------------

variable "network_name" {
  description = "Name of the network"
  type        = string
  default     = "cluster-network"
}

variable "database_name" {
  description = "Name of the DB"
  type        = string
  default     = "prodigy-db"
}

variable "database_user" {
  default = "prodigy-postgres"
}

variable "repository_id" {
  description = "Repository ID for container registry"
  type        = string
  default     = "cluster-docker"
}

variable "external_artifact_repos" {
  description = "External Artifact Registry repositories (cross-project) the cluster nodes should have read access to."
  type = list(object({
    project  = string
    location = string
    name     = string
  }))
  default = []
}

# ------------
# Cloud costs
# ------------
# Both default off: cost features activate nothing by existing.

variable "enable_cost_allocation" {
  description = "Enable GKE cost allocation (per-pod cost attribution in the billing export). Data only accrues from enablement onward."
  type        = bool
  default     = false
}

variable "enable_cost_collection" {
  description = "Provision read access to this cluster's rows of the billing export: an authorized view in the billing project plus a grant to the cluster's node SA. Requires billing_export."
  type        = bool
  default     = false
}

variable "billing_export" {
  description = "Location of the BigQuery billing export (enabled once per billing account, in the Billing console — not by Terraform). Required when enable_cost_collection is true."
  type = object({
    project  = string
    dataset  = string
    table    = string
    location = optional(string, "EU")
  })
  default = null
}

