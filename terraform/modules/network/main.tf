resource "google_compute_network" "vpc" {
  name                    = "${var.cluster_id}-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "nodes_subnet" {
  name          = "${var.cluster_id}-nodes-subnet"
  ip_cidr_range = var.subnet_cidr
  region        = var.region
  network       = google_compute_network.vpc.self_link
}

resource "google_compute_address" "reserved" {
  for_each = var.reserved_ips

  name         = "${var.cluster_id}-${each.key}-ip"
  address_type = "INTERNAL"
  address      = each.value
  region       = var.region
  subnetwork   = google_compute_subnetwork.nodes_subnet.id
}

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
  name       = "${var.cluster_id}-private-zone"
  dns_name   = "${var.cluster_domain}."
  visibility = "private"

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

  source_ranges = [var.subnet_cidr]
}

resource "google_compute_firewall" "bastion_ingress" {
  name        = "${var.cluster_id}-allow-bastion-ingress"
  network     = google_compute_network.vpc.name
  target_tags = ["${var.cluster_id}-bastion"]

  allow {
    protocol = "tcp"
    ports    = ["22", "80", "443", "6443", "22623", "8080", "9000"]
  }

  source_ranges = var.admin_source_ranges
}
