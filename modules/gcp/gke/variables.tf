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

variable "vpc_peering_dependency" {
  description = "Opaque ordering handle: pass an output of any resource that peers with the VPC (e.g. a Cloud SQL service networking connection) to make this module's own peering operations (GKE private control plane, Filestore) wait for it. GCP allows only one peering operation per network at a time."
  type        = any
  default     = null
}

# ----
# IAM
# ----

variable "buckets" {
  description = "Names (not self_links) of the buckets the cluster's workloads can read and write."
  type        = list(string)
  default     = []
}

variable "artifact_repos" {
  description = "Artifact repositories the cluster should have WRITE access to (the cluster's own repos, e.g. for publishing ad-hoc recipe images)."
  type        = list(any)
  default     = []
}

variable "readonly_artifact_repos" {
  description = "Artifact repositories the cluster should have READ-ONLY access to (e.g. the shared release registry images are pulled from). Repos here must never receive writer grants: user clusters must not be able to publish to shared registries."
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

variable "shared_storage_stage" {
  description = <<-EOT
    Which Filestore backs the cluster's shared ReadWriteMany volume. The
    legacy volume is a Terraform-managed 1 TiB instance (the floor for
    instances created directly); the CSI volume is provisioned by GKE's
    Filestore CSI driver, which allows Basic HDD down to 100 GiB. Clusters
    move one stage at a time, and only "csi" deletes the legacy instance:
      legacy    — legacy instance only (PVC prodigy-nfs).
      migrating — both exist; workloads still use the legacy volume. Copy
                  the data across in this stage.
      cutover   — both exist; workloads use the CSI volume (PVC
                  prodigy-shared). The legacy instance is kept for rollback.
      csi       — CSI volume only. Destroys the legacy instance and its data.
  EOT
  type        = string
  default     = "legacy"

  validation {
    condition     = contains(["legacy", "migrating", "cutover", "csi"], var.shared_storage_stage)
    error_message = "shared_storage_stage must be one of: legacy, migrating, cutover, csi."
  }
}

variable "shared_volume_capacity_gb" {
  description = "Capacity of the CSI-provisioned Filestore volume in GiB (Basic HDD minimum 100). Can grow in place, never shrink."
  type        = number
  default     = 100
}

variable "filestore_tier" {
  description = "Service tier of the legacy Filestore instance."
  type        = string
  default     = "BASIC_HDD"
}

variable "filestore_capacity_gb" {
  description = "Capacity of the legacy Filestore instance in GB (minimum 1024 for BASIC_HDD)."
  type        = number
  default     = 1024
}

variable "filestore_share_name" {
  description = "Name of the legacy Filestore instance's file share."
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

variable "enable_cost_allocation" {
  description = "Enable GKE cost allocation: node costs in the billing export are split per pod (by resource requests) and rows carry the pods' k8s labels. Attribution data only accrues from enablement onward, so enable early if per-workload cost breakdown is ever wanted."
  type        = bool
  default     = false
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
