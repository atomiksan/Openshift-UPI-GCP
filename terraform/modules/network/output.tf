output "network_name" {
  value = google_compute_network.vpc.name
}

output "nodes_subnet_id" {
  value = google_compute_subnetwork.nodes_subnet.id
}

output "reserved_ips" {
  value = { for name, address in google_compute_address.reserved : name => address.address }
}

output "private_zone_name" {
  value = google_dns_managed_zone.ocp_private_zone.name
}
