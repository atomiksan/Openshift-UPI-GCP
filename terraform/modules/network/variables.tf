variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
}

variable "cluster_id" {
  description = "OpenShift cluster name"
  type        = string
}

variable "cluster_domain" {
  description = "Fully qualified OpenShift cluster domain"
  type        = string
}

variable "subnet_cidr" {
  description = "CIDR range for the OpenShift node subnet"
  type        = string
}

variable "reserved_ips" {
  description = "Private IPs to reserve in the OpenShift subnet"
  type        = map(string)
}

variable "admin_source_ranges" {
  description = "Source ranges allowed to reach the bastion public services"
  type        = list(string)
}
