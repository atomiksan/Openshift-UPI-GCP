provider "google" {
  project     = var.project_id
  region      = var.region
  credentials = var.credentials_file == null ? null : file(var.credentials_file)
}

locals {
  cluster_domain = "${var.cluster_id}.${var.base_domain}"

  node_a_records = {
    bastion   = module.network.reserved_ips["bastion"]
    bootstrap = module.network.reserved_ips["bootstrap"]
    master0   = module.network.reserved_ips["master0"]
    master1   = module.network.reserved_ips["master1"]
    master2   = module.network.reserved_ips["master2"]
    worker0   = module.network.reserved_ips["worker0"]
    worker1   = module.network.reserved_ips["worker1"]
  }

  load_balanced_a_records = {
    api       = module.network.reserved_ips["bastion"]
    "api-int" = module.network.reserved_ips["bastion"]
  }
}

module "network" {
  source              = "./modules/network"
  project_id          = var.project_id
  region              = var.region
  cluster_id          = var.cluster_id
  cluster_domain      = local.cluster_domain
  subnet_cidr         = var.subnet_cidr
  reserved_ips        = var.reserved_ips
  admin_source_ranges = var.admin_source_ranges
}

resource "google_dns_record_set" "node_a" {
  for_each = local.node_a_records

  name         = "${each.key}.${local.cluster_domain}."
  type         = "A"
  ttl          = 60
  managed_zone = module.network.private_zone_name
  rrdatas      = [each.value]
}

resource "google_dns_record_set" "load_balanced_a" {
  for_each = local.load_balanced_a_records

  name         = "${each.key}.${local.cluster_domain}."
  type         = "A"
  ttl          = 60
  managed_zone = module.network.private_zone_name
  rrdatas      = [each.value]
}

resource "google_dns_record_set" "apps_wildcard" {
  name         = "*.apps.${local.cluster_domain}."
  type         = "A"
  ttl          = 60
  managed_zone = module.network.private_zone_name
  rrdatas      = [module.network.reserved_ips["bastion"]]
}

resource "google_dns_record_set" "etcd_srv" {
  name         = "_etcd-server-ssl._tcp.${local.cluster_domain}."
  type         = "SRV"
  ttl          = 60
  managed_zone = module.network.private_zone_name
  rrdatas = [
    "0 10 2380 master0.${local.cluster_domain}.",
    "0 10 2380 master1.${local.cluster_domain}.",
    "0 10 2380 master2.${local.cluster_domain}.",
  ]
}

module "compute" {
  source                   = "./modules/compute"
  project_id               = var.project_id
  region                   = var.region
  zone                     = var.zone
  cluster_id               = var.cluster_id
  nodes_subnet_id          = module.network.nodes_subnet_id
  reserved_ips             = module.network.reserved_ips
  rhcos_image              = var.rhcos_image
  bastion_image            = var.bastion_image
  service_account_email    = var.service_account_email
  ignition_mode            = var.ignition_mode
  ignition_base_url        = var.ignition_base_url
  ignition_version         = var.ignition_version
  ignition_dir             = abspath("${path.root}/${var.ignition_dir}")
  bastion_enable_public_ip = var.bastion_enable_public_ip
  haproxy_stats_user       = var.haproxy_stats_user
  haproxy_stats_password   = var.haproxy_stats_password

  depends_on = [
    google_dns_record_set.apps_wildcard,
    google_dns_record_set.etcd_srv,
    google_dns_record_set.load_balanced_a,
    google_dns_record_set.node_a,
  ]
}

output "cluster_domain" {
  value = local.cluster_domain
}

output "reserved_ips" {
  value = module.network.reserved_ips
}

output "bastion_public_ip" {
  value = module.compute.bastion_public_ip
}

output "bastion_private_ip" {
  value = module.compute.bastion_private_ip
}

output "bootstrap_private_ip" {
  value = module.compute.bootstrap_private_ip
}

output "master_private_ips" {
  value = module.compute.master_private_ips
}

output "worker_private_ips" {
  value = module.compute.worker_private_ips
}
