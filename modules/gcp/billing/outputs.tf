output "cost_view_table" {
  description = "Fully-qualified BigQuery table reference of the cluster's cost view, for the cost collector's query config."
  value       = "${var.billing_project}.${google_bigquery_dataset.cost_view.dataset_id}.${google_bigquery_table.cost_view.table_id}"
}
