# -----------------------
# Where you're deploying
# -----------------------

variable "prefix" {
  description = "Prefix to attach to resource names."
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

# -------
# Network
# -------

variable "vnet_subnet_id" {
  description = "Subnet ID for AKS nodes."
  type        = string
}

# ---------------------
# Options and settings
# ---------------------

variable "worker_types" {
  description = "Configurations for worker node pools. Each entry becomes an AKS node pool."
  type = map(
    object({
      name       = string
      node_class = string
      vm_size    = string
      spot       = optional(bool, false)
      min_size   = number
      max_size   = number
      gpu = optional(object({
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

# ----------
# Namespace
# ----------

variable "k8s_namespace" {
  description = "Kubernetes namespace for PVCs and other namespaced resources."
  type        = string
  default     = "prodigy-teams"
}

# ----------------
# Azure Files NFS
# ----------------

variable "storage_account_name" {
  description = "Globally unique storage account name for Azure Files NFS (alphanumeric, 3-24 chars)."
  type        = string
}

variable "nfs_storage_gb" {
  description = "Azure Files NFS share quota in GB."
  type        = number
  default     = 1024
}

# -----------
# AKS config
# -----------

variable "cluster_version" {
  description = "AKS Kubernetes version. If null, uses the latest stable."
  type        = string
  default     = null
}

variable "system_node_pool_vm_size" {
  description = "VM size for the system (default) node pool."
  type        = string
  default     = "Standard_D2s_v3"
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

variable "database_host" {
  description = "Database host to store in the infra K8s Secret."
  type        = string
}

variable "database_user" {
  description = "Database user to store in the infra K8s Secret."
  type        = string
}

variable "database_name" {
  description = "Database name to store in the infra K8s Secret."
  type        = string
}
