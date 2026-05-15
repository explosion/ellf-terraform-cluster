variable "prefix" {
  description = "Prefix for resource names."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for the database subnet group."
  type        = string
}

variable "subnet_ids" {
  description = "Private subnet IDs for the database subnet group."
  type        = list(string)
}

variable "vpc_cidr" {
  description = "VPC CIDR block, used to allow inbound database connections."
  type        = string
}

variable "user" {
  description = "Master database username."
  type        = string
}

variable "name" {
  description = "Name of the database to create."
  type        = string
}

variable "instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.t3.small"
}

variable "engine_version" {
  description = "PostgreSQL engine version."
  type        = string
  default     = "14"
}
