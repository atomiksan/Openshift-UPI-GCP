provider "google" {
  project     = var.project_id
  region      = var.region
  credentials = file("${path.root}/../ocp-sa-key.json")
}

# 1. Create Network (VPC, Subnets, NAT)
module "network" {
  source      = "./modules/network"
  project_id  = var.project_id
  region      = var.region
  cluster_id  = var.cluster_id
  base_domain = var.base_domain
}

# 2. Create Compute (Bootstrap & Masters)
module "compute" {
  source          = "./modules/compute"
  project_id      = var.project_id
  region          = var.region
  cluster_id      = var.cluster_id
  nodes_subnet_id = module.network.nodes_subnet_id
  rhcos_image     = "projects/vernal-branch-484810-p6/global/images/rhcos-420"
}

# 3. DNS Records (Moved here to break the cycle)
resource "google_dns_record_set" "api" {
  name         = "api.${var.cluster_id}.ocp.${var.base_domain}."
  type         = "A"
  ttl          = 60
  managed_zone = module.network.zone_name
  # Point to Bootstrap PUBLIC IP + Master PUBLIC IPs (if they had any, but they don't)
  # For UPI on GCP without a real LB, we at least keep bootstrap here.
  # If masters were public, we'd add them. Since they are private, external 'api' usually stays on bootstrap.
  rrdatas      = [module.compute.bootstrap_public_ip]
}

resource "google_dns_record_set" "api_int" {
  name         = "api-int.${var.cluster_id}.ocp.${var.base_domain}."
  type         = "A"
  ttl          = 60
  managed_zone = module.network.private_zone_name
  # Round-robin: Bootstrap IP + All Master IPs
  rrdatas      = concat([module.compute.bootstrap_private_ip], module.compute.master_private_ips)
}

resource "google_dns_record_set" "master" {
  count        = 3
  name         = "master-${count.index}.ocp.${var.base_domain}."
  type         = "A"
  ttl          = 60
  managed_zone = module.network.private_zone_name
  rrdatas      = [module.compute.master_private_ips[count.index]]
}

resource "google_dns_record_set" "apps" {
  name         = "*.apps.${var.cluster_id}.ocp.${var.base_domain}."
  type         = "A"
  ttl          = 300
  managed_zone = module.network.zone_name
  # Pointing to Bootstrap Public IP so you can reach the console later
  rrdatas      = [module.compute.bootstrap_public_ip] 
}


output "nameservers" {
  value = module.network.nameservers
}
