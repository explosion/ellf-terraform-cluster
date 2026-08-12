locals {
  # One dataset per cluster in the billing project, so per-cluster
  # create/destroy never contends with other clusters' views.
  view_dataset_id = "cost_view_${replace(var.gcp_project, "-", "_")}"
  view_table_id   = "billing_export"
}

resource "google_bigquery_dataset" "cost_view" {
  project     = var.billing_project
  dataset_id  = local.view_dataset_id
  location    = var.billing_export_location
  description = "Authorized view over the billing export, filtered to project ${var.gcp_project}."
}

resource "google_bigquery_table" "cost_view" {
  project             = var.billing_project
  dataset_id          = google_bigquery_dataset.cost_view.dataset_id
  table_id            = local.view_table_id
  deletion_protection = false # a view over the export; trivially recreated

  view {
    use_legacy_sql = false
    query          = <<-SQL
      SELECT *
      FROM `${var.billing_project}.${var.billing_export_dataset}.${var.billing_export_table}`
      WHERE project.id = "${var.gcp_project}"
    SQL
  }
}

# Authorize the view against the export dataset: the view (not its
# readers) gets permission to read the underlying export table, so
# readers of the view can never see other clusters' rows.
resource "google_bigquery_dataset_access" "authorize_view" {
  project    = var.billing_project
  dataset_id = var.billing_export_dataset

  view {
    project_id = var.billing_project
    dataset_id = google_bigquery_dataset.cost_view.dataset_id
    table_id   = google_bigquery_table.cost_view.table_id
  }
}

# The cluster's SA can read its view — table-level IAM only, never
# dataset- or project-level in the billing project.
resource "google_bigquery_table_iam_member" "view_reader" {
  project    = var.billing_project
  dataset_id = google_bigquery_dataset.cost_view.dataset_id
  table_id   = google_bigquery_table.cost_view.table_id
  role       = "roles/bigquery.dataViewer"
  member     = "serviceAccount:${var.service_account_email}"
}

# Query jobs run in the cluster's own project, so BigQuery query cost
# for cost-collection lands on the cluster being metered.
resource "google_project_iam_member" "job_user" {
  project = var.gcp_project
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${var.service_account_email}"
}
