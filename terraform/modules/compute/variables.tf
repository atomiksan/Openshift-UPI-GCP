variable "project_id" {}
variable "region"     {}
variable "cluster_id" {}
variable "nodes_subnet_id" {
  description = "The ID of the subnet created in the network module"
  type        = string
}
variable "rhcos_image" {
  description = "The self_link of the RHCOS image in GCP"
  type        = string
}
