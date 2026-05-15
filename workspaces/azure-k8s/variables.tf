variable "location" {
  description = "Azure region for all resources (e.g. westeurope)."
  type        = string
}

variable "resource_group_name" {
  description = "Name of the Azure resource group."
  type        = string
}

variable "domain" {
  description = "Domain name for the cluster ingress."
  type        = string
}

variable "worker_types" {
  description = "Configurations for worker node pools."
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

variable "system_node_pool_vm_size" {
  description = "VM size for the system node pool."
  type        = string
  default     = "Standard_D2s_v3"
}

variable "system_node_pool_size" {
  description = "Number of nodes in the system node pool."
  type        = number
  default     = 1
}

variable "network_name" {
  description = "Name for the virtual network."
  type        = string
  default     = "cluster-network"
}

variable "vnet_cidr" {
  description = "CIDR block for the virtual network."
  type        = string
  default     = "10.0.0.0/16"
}

variable "database_name" {
  description = "Name of the database."
  type        = string
  default     = "prodigy_db"
}

variable "database_user" {
  description = "Database administrator username."
  type        = string
  default     = "prodigy_postgres"
}

variable "acr_name" {
  description = "Globally unique Azure Container Registry name (alphanumeric, 5-50 chars)."
  type        = string
}

variable "storage_account_name" {
  description = "Globally unique storage account name for NFS (alphanumeric, 3-24 chars)."
  type        = string
}

variable "data_storage_account_name" {
  description = "Globally unique storage account name for data (alphanumeric, 3-24 chars)."
  type        = string
}
