# Define the Google Cloud provider and project.
provider "google" {
  project = var.project_id
  region  = var.region
}