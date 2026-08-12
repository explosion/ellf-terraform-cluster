# -----------------------------------------------------------------
# Per-cluster read access to a shared BigQuery billing export.
#
# GCP has no per-project cost API: itemized spend only exists in the
# billing export, which is configured per *billing account* into a
# single dataset. This module carves out project-scoped access with
# an authorized view (WHERE project.id = <cluster project>) so the
# cluster's service account can read its own cost rows and nothing
# else.
#
# NOTE: the billing export itself cannot be created by Terraform —
# it is enabled once per billing account in the Billing console.
# This module only consumes an existing export.
# -----------------------------------------------------------------

variable "gcp_project" {
  description = "The cluster's own project. Cost rows are filtered to this project, and the service account is granted bigquery.jobUser here so query jobs (and their cost) run in the cluster's project."
  type        = string
}

variable "service_account_email" {
  description = "Service account to grant read access to the cluster's cost view (the cluster's workload-identity node SA)."
  type        = string
}

variable "billing_project" {
  description = "The central project containing the billing export dataset."
  type        = string
}

variable "billing_export_dataset" {
  description = "Dataset ID of the billing export in the billing project."
  type        = string
}

variable "billing_export_table" {
  description = "Table ID of the billing export, e.g. gcp_billing_export_resource_v1_XXXXXX_XXXXXX_XXXXXX."
  type        = string
}

variable "billing_export_location" {
  description = "Location of the billing export dataset. The view's dataset must be in the same location to query it."
  type        = string
  default     = "EU"
}
