output "bootstrap_public_ip" { value = google_compute_instance.bootstrap.network_interface[0].access_config[0].nat_ip }
output "bootstrap_private_ip" { value = google_compute_instance.bootstrap.network_interface[0].network_ip }
output "master_private_ips" { value = google_compute_instance.master[*].network_interface[0].network_ip }
