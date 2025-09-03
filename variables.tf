variable "project_id" {   
    description = "The GCP project ID where resources will be created."
    type = string
}

variable region {
    description = "The GCP region where resources will be created."
    type        = string
    default     = "us-central1"
}

variable app_name {
    description = "The name of the application."
    type        = string
    default     = "email-agent"
}