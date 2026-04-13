variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
}

variable "zone" {
  description = "GCP zone"
  type        = string
}

variable "cluster_id" {
  description = "OpenShift cluster name"
  type        = string
}

variable "nodes_subnet_id" {
  description = "The ID of the subnet created in the network module"
  type        = string
}

variable "reserved_ips" {
  description = "Reserved private IPs keyed by role"
  type        = map(string)
}

variable "rhcos_image" {
  description = "The self_link of the RHCOS image in GCP"
  type        = string
}

variable "bastion_image" {
  description = "Boot image for the bastion/load balancer instance"
  type        = string
}

variable "service_account_email" {
  description = "Optional service account email attached to OpenShift instances"
  type        = string
  default     = null
}

variable "ignition_mode" {
  description = "Use url to pass pointer configs, or file to pass local ignition files directly"
  type        = string
}

variable "ignition_base_url" {
  description = "Base URL used when ignition_mode is url"
  type        = string
}

variable "ignition_version" {
  description = "Ignition spec version used for generated URL pointer configs"
  type        = string
}

variable "ignition_dir" {
  description = "Absolute path to ignition files when ignition_mode is file"
  type        = string
}

variable "bastion_enable_public_ip" {
  description = "Attach an ephemeral public IP to the bastion"
  type        = bool
}

variable "haproxy_stats_user" {
  description = "HAProxy stats username"
  type        = string
}

variable "haproxy_stats_password" {
  description = "HAProxy stats password"
  type        = string
  sensitive   = true
}
