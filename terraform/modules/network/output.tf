output "nodes_subnet_id" { value = google_compute_subnetwork.nodes_subnet.id }
output "zone_name" { value = google_dns_managed_zone.ocp_zone.name }
output "nameservers" {
  value = google_dns_managed_zone.ocp_zone.name_servers
}

output "private_zone_name" {
  value = google_dns_managed_zone.ocp_private_zone.name
}
