

# --- Service Account and IAM Roles ---
# Create a dedicated service account for the application.
resource "google_service_account" "api_service_account" {
  account_id   = "email-agent-api"
  display_name = "Email Agent API Service Account"
}

# Grant the service account permissions to run and manage services.
resource "google_project_iam_member" "service_account_iam" {
  for_each = toset([
    "roles/run.admin",
    "roles/storage.admin",
    "roles/datastore.user",
    "roles/cloudfunctions.admin",
    "roles/iam.serviceAccountUser",
    "roles/pubsub.editor",
    "roles/artifactregistry.writer"
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.api_service_account.email}"
}

# --- API Enabling ---
# Enable all necessary GCP APIs for the project.
resource "google_project_service" "apis" {
  for_each = toset([
    "run.googleapis.com",
    "cloudbuild.googleapis.com",
    "artifactregistry.googleapis.com",
    "storage.googleapis.com",
    "firestore.googleapis.com",
    "pubsub.googleapis.com",
    "cloudfunctions.googleapis.com",
    "sqladmin.googleapis.com",
    "iam.googleapis.com",
    "aiplatform.googleapis.com" # For Vertex AI and Gemini access
  ])

  service = each.value
  disable_on_destroy = false
}

# --- Frontend Hosting Resources ---
# Create a Google Cloud Storage bucket for the static frontend.
resource "google_storage_bucket" "frontend_bucket" {
  name          = "${var.app_name}-frontend-bucket"
  location      = "US-CENTRAL1"
  force_destroy = true

  website {
    main_page_suffix = "index.html"
    not_found_page   = "index.html"
  }
}

# Make the bucket content publicly readable.
resource "google_storage_bucket_iam_member" "frontend_bucket_iam" {
  bucket = google_storage_bucket.frontend_bucket.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}

# --- Backend & Agent Orchestration (Cloud Run) ---
# Create an Artifact Registry repository for container images.
resource "google_artifact_registry_repository" "api_repo" {
  location      = var.region
  repository_id = "${var.app_name}-api-repo"
  format        = "DOCKER"
}

# Deploy the backend API to Cloud Run.
resource "google_cloud_run_v2_service" "api_service" {
  name     = "${var.app_name}-api-service"
  location = var.region

  template {
    containers {
      image = "us-central1-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.api_repo.repository_id}/${var.app_name}-api:latest"
    }

    service_account = google_service_account.api_service_account.email
  }

  ingress = "INGRESS_TRAFFIC_ALL"
}

# --- Data Stores ---
# Create a Firestore instance in Datastore mode.
resource "google_firestore_database" "firestore_db" {
  name     = "(default)"
  location_id = "us-central1"
  type = "FIRESTORE_NATIVE"
}

# Create a Cloud SQL (PostgreSQL) instance for structured data.
resource "google_sql_database_instance" "sql_db_instance" {
  name             = "${var.app_name}-sql-instance"
  database_version = "POSTGRES_14"
  region           = var.region

  settings {
    tier = "db-f1-micro"
    backup_configuration {
      enabled = true
    }
  }
}

# --- Asynchronous Processing (Pub/Sub & Cloud Functions) ---
# Create a Pub/Sub topic to trigger async tasks.
resource "google_pubsub_topic" "agent_task_topic" {
  name = "${var.app_name}-agent-tasks"
}

# Create a Cloud Storage bucket to store the Cloud Function's source code.
resource "google_storage_bucket" "function_source_bucket" {
  name          = "${var.app_name}-function-source"
  location      = "US-CENTRAL1"
  force_destroy = true
}

# Define the Cloud Function that will be triggered by Pub/Sub.
resource "google_cloudfunctions2_function" "async_agent_function" {
  name     = "${var.app_name}-async-agent"
  location = var.region

  build_config {
    runtime = "nodejs18"
    entry_point = "runAgentTask"
    source {
      storage_source {
        bucket = google_storage_bucket.function_source_bucket.name
        object = "source.zip"
      }
    }
  }

  service_config {
    service_account_email = google_service_account.api_service_account.email
    min_instance_count = 0
    max_instance_count = 2
  }
  
  event_trigger {
    trigger_region = "us-central1"
    event_type = "google.cloud.pubsub.topic.v1.messagePublished"
    pubsub_topic = google_pubsub_topic.agent_task_topic.id
  }
}

# --- Outputs ---
# Provides useful information after the 'terraform apply' is complete.
output "frontend_bucket_url" {
  value = "http://storage.googleapis.com/${google_storage_bucket.frontend_bucket.name}"
}

output "cloud_run_service_url" {
  value = google_cloud_run_v2_service.api_service.uri
}
