variable "aws_region" {
  description = "AWS region for all resources."
  type        = string
}

variable "domain" {
  description = "Domain name for the cluster ingress."
  type        = string
}

variable "enable_ssh" {
  description = "Enable SSH access to nodes."
  type        = bool
  default     = true
}

variable "worker_types" {
  description = "Configurations for worker node pools."
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

variable "network_name" {
  description = "Name tag for the VPC."
  type        = string
  default     = "cluster-network"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "database_name" {
  description = "Name of the database."
  type        = string
  default     = "prodigy_db"
}

variable "database_user" {
  description = "Database master username."
  type        = string
  default     = "prodigy_postgres"
}

variable "repository_name" {
  description = "ECR repository name."
  type        = string
  default     = "cluster-docker"
}
