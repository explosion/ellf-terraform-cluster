# -----------------------
# Where you're deploying
# -----------------------

variable "aws_region" {
  description = "AWS region for all resources."
  type        = string
}

variable "prefix" {
  description = "Prefix to attach to resource names."
  type        = string
}

# -------
# Network
# -------

variable "vpc_id" {
  description = "VPC ID for the cluster."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for EKS nodes and EFS mount targets."
  type        = list(string)
}

# ---------------------
# Options and settings
# ---------------------

variable "enable_ssh" {
  description = "Enable SSH access to nodes."
  type        = bool
  default     = true
}

variable "worker_types" {
  description = "Configurations for worker node pools. Each entry becomes an EKS managed node group."
  type = map(
    object({
      name          = string
      node_class    = string
      instance_type = string
      spot          = optional(bool, false)
      min_size      = number
      max_size      = number
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
  default     = "ellf"
}

# ---
# EFS
# ---

variable "efs_performance_mode" {
  description = "EFS performance mode."
  type        = string
  default     = "generalPurpose"
}

variable "efs_throughput_mode" {
  description = "EFS throughput mode."
  type        = string
  default     = "bursting"
}

variable "efs_capacity_gb" {
  description = "Capacity to request for the EFS-backed PVC (in GB)."
  type        = number
  default     = 1024
}

# -----------
# EKS config
# -----------

variable "cluster_version" {
  description = "EKS Kubernetes version."
  type        = string
  default     = "1.29"
}

variable "system_node_pool_instance_type" {
  description = "Instance type for the system node pool."
  type        = string
  default     = "t3.medium"
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
