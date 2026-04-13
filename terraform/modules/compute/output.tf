output "bastion_private_ip" {
  value = google_compute_instance.bastion.network_interface[0].network_ip
}

output "bastion_public_ip" {
  value = try(google_compute_instance.bastion.network_interface[0].access_config[0].nat_ip, null)
}

output "bootstrap_private_ip" {
  value = google_compute_instance.bootstrap.network_interface[0].network_ip
}

output "master_private_ips" {
  value = { for name, instance in google_compute_instance.master : name => instance.network_interface[0].network_ip }
}

output "worker_private_ips" {
  value = { for name, instance in google_compute_instance.worker : name => instance.network_interface[0].network_ip }
}
