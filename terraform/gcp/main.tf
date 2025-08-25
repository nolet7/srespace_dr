terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.40"
    }
  }
}

provider "google" {
  project = var.project_id
}

variable "project_id" { type = string }
variable "bucket"     { type = string }
variable "gsa_name"   { type = string }

resource "google_service_account" "velero" {
  account_id   = var.gsa_name
  display_name = "Velero GSA"
}

resource "google_storage_bucket" "velero" {
  name                        = var.bucket
  location                    = "US"
  uniform_bucket_level_access = true
  versioning { enabled = true }
  force_destroy = false
}

resource "google_storage_bucket_iam_member" "admin" {
  bucket = google_storage_bucket.velero.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.velero.email}"
}

output "bucket"    { value = google_storage_bucket.velero.name }
output "gsa_email" { value = google_service_account.velero.email }
