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

variable "worker_types" {
  description = "Configurations for worker node pools. Each entry becomes a GKE node pool."
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

variable "ingress_ip_name" {
  description = "Name of the pre-reserved regional static IP for the ingress LoadBalancer."
  type        = string
  default     = "cluster-lb-ip"
}

variable "healthcheck_path" {
  description = "Health check path for the ingress backend."
  type        = string
  default     = "/healthz"
}

# ----------
# Namespace
# ----------

variable "k8s_namespace" {
  description = "Kubernetes namespace for PVCs and other namespaced resources."
  type        = string
  default     = "ellf"
}

variable "k8s_service_account" {
  description = "Kubernetes service account name for Workload Identity binding."
  type        = string
  default     = "ellf"
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

# -----------
# GKE config
# -----------

variable "release_channel" {
  description = "GKE release channel (UNSPECIFIED, RAPID, REGULAR, STABLE)."
  type        = string
  default     = "REGULAR"
}

variable "cluster_version" {
  description = "Minimum master version. If unset, uses release channel default."
  type        = string
  default     = null
}

variable "system_node_pool_machine_type" {
  description = "Machine type for the system (default) node pool."
  type        = string
  default     = "e2-medium"
}

variable "system_node_pool_size" {
  description = "Number of nodes in the system node pool."
  type        = number
  default     = 1
}

# -------
# Secrets
# -------

variable "database_password" {
  description = "Database password to store in the infra K8s Secret."
  type        = string
  sensitive   = true
}
