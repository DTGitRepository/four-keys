resource "google_bigquery_dataset" "four_keys" {
  dataset_id = "four_keys"
}

# TODO: these table creation statements might not be necessary.
# When scheduled queries are implemented, try removing this.
# (see https://github.com/GoogleCloudPlatform/fourkeys/pull/90#discussion_r604320593)
resource "google_bigquery_table" "bq_table" {
  for_each   = toset(["events_raw", "changes", "deployments", "incidents"])
  dataset_id = google_bigquery_dataset.four_keys.dataset_id
  table_id   = each.key
  schema     = file("../../setup/${each.key}_schema.json")
}

resource "google_service_account" "event_handler_service_account" {
  account_id   = "event-handler"
  display_name = "Service Account for Event Handler Cloud Run Service"
}

module "event_handler_service" {
  source            = "./cloud_run_service"
  google_project_id = var.google_project_id
  google_region     = var.google_region
  service_name      = "event-handler"
  service_account   = google_service_account.event_handler_service_account.email

  depends_on = [
    google_project_service.run_api,
  ]

}

resource "google_secret_manager_secret" "event-handler-secret" {
  secret_id = "event-handler"
  replication {
    automatic = true
  }
  depends_on = [google_project_service.sm_api]
}

resource "random_id" "event-handler-random-value" {
  byte_length = "20"
}

resource "google_secret_manager_secret_version" "event-handler-secret-version" {
  secret      = google_secret_manager_secret.event-handler-secret.id
  secret_data = random_id.event-handler-random-value.hex
}

resource "google_secret_manager_secret_iam_member" "event-handler" {
  secret_id = google_secret_manager_secret.event-handler-secret.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.event_handler_service_account.email}"
}