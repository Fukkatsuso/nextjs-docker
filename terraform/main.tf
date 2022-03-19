terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "3.5.0"
    }
  }

  backend "gcs" {
    bucket = "nextjs-docker-tfstate"
  }
}

provider "google" {
  credentials = var.credentials

  project = var.project
  region  = var.region
}

# Enable the Cloud Resource Manager API
resource "google_project_service" "crm_api" {
  service = "cloudresourcemanager.googleapis.com"

  disable_on_destroy = true
}

# Enable the Cloud Run API
resource "google_project_service" "run_api" {
  service = "run.googleapis.com"

  disable_on_destroy = true

  depends_on = [google_project_service.crm_api]
}

resource "google_cloud_run_service" "app" {
  name     = "nextjs-docker"
  location = var.region

  template {
    spec {
      containers {
        image = var.container_image
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }

  # Waits for the Cloud Run API to be enabled
  depends_on = [google_project_service.run_api]
}

# Allow unauthenticated users to invoke the service
data "google_iam_policy" "noauth" {
  binding {
    role = "roles/run.invoker"
    members = [
      "allUsers",
    ]
  }
}

resource "google_cloud_run_service_iam_policy" "noauth" {
  location = google_cloud_run_service.app.location
  project  = google_cloud_run_service.app.project
  service  = google_cloud_run_service.app.name

  policy_data = data.google_iam_policy.noauth.policy_data
}
