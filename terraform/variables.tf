variable "project_id" {
  description = "The GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP zone for the bastion and OpenShift instances"
  type        = string
  default     = "us-central1-a"
}

variable "cluster_id" {
  description = "OpenShift cluster name"
  type        = string
  default     = "ocp-lab"
}

variable "base_domain" {
  description = "Base domain. The cluster FQDN becomes <cluster_id>.<base_domain>."
  type        = string
  default     = "ocp.satyabrata.net"
}

variable "credentials_file" {
  description = "Optional path to a Google service account JSON key. Leave null to use ADC/gcloud credentials."
  type        = string
  default     = null
}

variable "subnet_cidr" {
  description = "CIDR range for the OpenShift node subnet"
  type        = string
  default     = "10.0.0.0/24"
}

variable "reserved_ips" {
  description = "Private IPs reserved in the OpenShift subnet"
  type        = map(string)
  default = {
    bastion   = "10.0.0.10"
    master0   = "10.0.0.11"
    master1   = "10.0.0.12"
    master2   = "10.0.0.13"
    worker0   = "10.0.0.14"
    worker1   = "10.0.0.15"
    bootstrap = "10.0.0.20"
  }
}

variable "admin_source_ranges" {
  description = "Source ranges allowed to reach the bastion public services"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "rhcos_image" {
  description = "RHCOS image self link to use for bootstrap, master, and worker instances"
  type        = string
}

variable "bastion_image" {
  description = "Boot image for the bastion/load balancer instance"
  type        = string
  default     = "projects/debian-cloud/global/images/family/debian-12"
}

variable "service_account_email" {
  description = "Optional service account email attached to OpenShift instances"
  type        = string
  default     = null
}

variable "ignition_mode" {
  description = "Use url to pass small pointer configs, or file to pass local ignition files directly"
  type        = string
  default     = "url"

  validation {
    condition     = contains(["url", "file"], var.ignition_mode)
    error_message = "ignition_mode must be either url or file."
  }
}

variable "ignition_base_url" {
  description = "Base URL used when ignition_mode is url"
  type        = string
  default     = "http://10.0.0.10:8080/ignition"
}

variable "ignition_version" {
  description = "Ignition spec version used for generated URL pointer configs"
  type        = string
  default     = "3.2.0"
}

variable "ignition_dir" {
  description = "Directory containing bootstrap.ign, master.ign, and worker.ign when ignition_mode is file"
  type        = string
  default     = "../ocp-install-config"
}

variable "bastion_enable_public_ip" {
  description = "Attach an ephemeral public IP to the bastion"
  type        = bool
  default     = true
}

variable "haproxy_stats_user" {
  description = "HAProxy stats username"
  type        = string
  default     = "admin"
}

variable "haproxy_stats_password" {
  description = "HAProxy stats password"
  type        = string
  default     = "change-me"
  sensitive   = true
}
