variable "project_id" {
  description = "The GCP Project ID"
  type        = string
  default     = "vernal-branch-484810-p6"
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "us-central1"
}

variable "cluster_id" {
  description = "Prefix for all resources"
  type        = string
  default     = "ocp-lab"
}

variable "base_domain" {
  description = "The renewed domain"
  type        = string
  default     = "satyabrata.net"
}
