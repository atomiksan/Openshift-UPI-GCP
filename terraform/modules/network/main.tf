resource "google_compute_network" "vpc" {
  name                    = "${var.cluster_id}-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "nodes_subnet" {
  name          = "${var.cluster_id}-nodes-subnet"
  ip_cidr_range = "10.0.0.0/24"
  region        = var.region
  network       = google_compute_network.vpc.self_link
}

resource "google_dns_managed_zone" "ocp_zone" {
  name        = "${var.cluster_id}-zone"
  dns_name    = "ocp.${var.base_domain}."
  visibility  = "public"
  
  //lifecycle { prevent_destroy = true }
}

# --- CLOUD NAT (The fix for the pull errors) ---
resource "google_compute_router" "router" {
  name    = "${var.cluster_id}-router"
  region  = var.region
  network = google_compute_network.vpc.id
}

resource "google_compute_router_nat" "nat" {
  name                               = "${var.cluster_id}-nat"
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

resource "google_dns_managed_zone" "ocp_private_zone" {
  name        = "${var.cluster_id}-private-zone"
  dns_name    = "ocp.${var.base_domain}."
  visibility  = "private"
  
  private_visibility_config {
    networks {
      network_url = google_compute_network.vpc.id
    }
  }
}

resource "google_compute_firewall" "internal" {
  name    = "${var.cluster_id}-allow-internal"
  network = google_compute_network.vpc.name
  allow { protocol = "icmp" }
  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }
  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }
  source_ranges = ["10.0.0.0/24"]
}

resource "google_compute_firewall" "external" {
  name    = "${var.cluster_id}-allow-external"
  network = google_compute_network.vpc.name
  allow {
    protocol = "tcp"
    ports    = ["6443", "22623", "22", "80", "443"] 
  }
  source_ranges = ["0.0.0.0/0"]
}
