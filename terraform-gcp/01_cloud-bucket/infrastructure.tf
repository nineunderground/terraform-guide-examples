terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "3.77.0"
    }
  }
}

provider "google" {
  project     = var.project_name
  region      = var.region
  zone        = var.zone
}

variable "project_name" {}

variable "region" {
  default = "europe-north1"
}

variable "zone" {
  default = "europe-north1"
}

resource "google_pubsub_schema" "topic_schema" {
  name       = "topic_schema"
  type       = "AVRO"
  definition = "{\"type\": \"myrecordtype\",\"name\": \"myrecordname\",\"fields\": [{ \"name\": \"created_at\", \"type\": \"string\" },{ \"name\": \"message_id\", \"type\": \"string\" },{ \"name\": \"message\", \"type\": \"string\" }]}"
}

resource "google_pubsub_topic" "my_topic" {
  name = "MY_TOPIC_NAME"

  depends_on = [google_pubsub_schema.topic_schema]
  schema_settings {
    schema   = "projects/${var.project_name}/schemas/topic_schema"
    encoding = "JSON"
  }
}
